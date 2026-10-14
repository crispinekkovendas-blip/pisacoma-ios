import SwiftUI

private let bg = Tokens.bg
private let gold = Tokens.accent
private let goldLight = Tokens.accentLight

/// The site's /videos: search bar + count, the hero, one rail per channel and category (Netflix-style), grid when searching.
struct VideosView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.openURL) private var openURL
    @StateObject private var model: VideosModel

    init() { _model = StateObject(wrappedValue: VideosModel(userState: AppModel.shared.userState)) }

    var body: some View {
        let s = model.state
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        IconView(name: "ic_nav_search", color: Color.white.opacity(0.6)).frame(width: 16, height: 16)
                        ZStack(alignment: .leading) {
                            if s.query.isEmpty { Text("Buscar videos…").font(Fonts.inter(14)).foregroundStyle(Color.white.opacity(0.5)) }
                            TextField("", text: Binding(get: { model.state.query }, set: { model.query($0) }))
                                .font(Fonts.inter(14)).foregroundStyle(.white).tint(gold).autocorrectionDisabled()
                                .uiId("videos-search")
                        }
                        if s.isSearching { IconView(name: "ic_nav_close", color: Color.white.opacity(0.7)).frame(width: 14, height: 14).pressable { model.query("") }.accessibilityLabel("Limpiar búsqueda") }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    Text("\(s.videos.count) videos").font(Fonts.inter(12)).foregroundStyle(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                if s.loading {
                    Text("Cargando el catálogo…").font(Fonts.inter(14)).foregroundStyle(Color.white.opacity(0.6)).frame(maxWidth: .infinity).padding(60)
                } else if s.offline {
                    VStack(spacing: 0) {
                        Text("Sin conexión").font(Fonts.playfair(26, weight: .semibold)).foregroundStyle(.white)
                        Spacer().frame(height: 8)
                        Text("El catálogo de videos necesita señal. Revisa tu conexión e inténtalo otra vez.").font(Fonts.inter(14.5)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.6)).multilineTextAlignment(.center)
                        Spacer().frame(height: 18)
                        Text("Reintentar").font(Fonts.inter(15, weight: .semibold)).foregroundStyle(bg)
                            .padding(.horizontal, 26).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [gold, goldLight], startPoint: .leading, endPoint: .trailing)))
                            .pressable(scale: 0.97, tag: "videos-retry") { model.load() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24).padding(.vertical, 60)
                    .uiId("videos-offline")
                } else if s.isSearching {
                    let res = s.results
                    HStack(spacing: 6) {
                        Text("\(res.count) resultado\(res.count != 1 ? "s" : "") para").font(Fonts.inter(13)).foregroundStyle(Color.white.opacity(0.6))
                        Text("\"\(s.query)\"").font(Fonts.inter(13, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    if res.isEmpty { Text("No se encontraron videos.").font(Fonts.inter(14)).foregroundStyle(Color.white.opacity(0.5)).padding(16) }
                    ForEach(res) { v in GridCard(video: v) { router.go(.video(id: v.videoId)) } }
                } else {
                    if let h = s.hero {
                        Hero(video: h, onPlay: { router.go(.video(id: h.videoId)) }, onYouTube: { openURL(URL(string: "https://www.youtube.com/watch?v=\(h.videoId)")!) })
                    }
                    ForEach(s.rows) { row in VideoRowView(row: row) { router.go(.video(id: $0.videoId)) } }
                }
                Spacer().frame(height: 30)
                SiteFooter()
            }
        }
        .background(bg)
        .uiId("videos-page")
    }
}

/// A YouTube thumbnail (hqdefault by default) in a dark box.
struct Thumb: View {
    let videoId: String
    var size = "hqdefault"
    var body: some View {
        AsyncImage(url: URL(string: VideoCatalog.thumb(videoId, size))) { phase in
            if let img = phase.image { img.resizable().scaledToFill() } else { Color(hex: 0x161B22) }
        }
    }
}

private struct Hero: View {
    let video: TaggedVideo
    let onPlay: () -> Void
    let onYouTube: () -> Void
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Thumb(videoId: video.videoId, size: "maxresdefault").aspectRatio(16 / 10, contentMode: .fit).clipped()
            LinearGradient(stops: [.init(color: .clear, location: 0.2), .init(color: bg, location: 1)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                Text("— MÁS RECIENTE").font(Fonts.inter(11, weight: .bold)).tracking(2).foregroundStyle(goldLight)
                Spacer().frame(height: 8)
                Text(video.title).font(Fonts.playfair(24, weight: .semibold)).foregroundStyle(.white).lineLimit(3)
                Spacer().frame(height: 6)
                Text(VideoCatalog.channelName + (video.published.map { " · \(VideoCatalog.relTimeEsIso($0))" } ?? "")).font(Fonts.inter(12.5)).foregroundStyle(Color.white.opacity(0.6)).lineLimit(1)
                Spacer().frame(height: 14)
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        IconView(name: "ic_play", color: bg).frame(width: 16, height: 16)
                        Text("Ver").font(Fonts.inter(15, weight: .bold)).foregroundStyle(bg)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white))
                    .pressable(scale: 0.97, tag: "hero-play", action: onPlay)
                    Text("Abrir en YouTube").font(Fonts.inter(14, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                        .pressable(scale: 0.97, action: onYouTube)
                }
            }
            .padding(16)
        }
        .uiId("videos-hero")
    }
}

private struct VideoRowView: View {
    let row: VideoRowUi
    let onPlay: (TaggedVideo) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(row.num).").font(Fonts.playfair(15, weight: .semibold)).foregroundStyle(gold)
                Text(row.label).font(Fonts.inter(16, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(String(row.videos.count)).font(Fonts.inter(12)).foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(row.videos) { v in
                        VStack(alignment: .leading, spacing: 6) {
                            Thumb(videoId: v.videoId).frame(width: 196, height: 110).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(v.title).font(Fonts.inter(12.5)).foregroundStyle(Color.white.opacity(0.85)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 196, alignment: .leading)
                        .pressable(scale: 0.97, tag: "video-\(v.videoId)") { onPlay(v) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 22)
        .uiId("row-\(row.key)")
    }
}

private struct GridCard: View {
    let video: TaggedVideo
    let onPlay: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Thumb(videoId: video.videoId).aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
            HStack(alignment: .top, spacing: 10) {
                ZStack { Circle().fill(Color(hex: 0x161B22)); IconView(name: "sda_symbol_circle", color: goldLight).frame(width: 22, height: 22) }.frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title).font(Fonts.inter(14, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                    Text(VideoCatalog.channelName + (video.published.map { " · \(VideoCatalog.relTimeEsIso($0))" } ?? "")).font(Fonts.inter(12)).foregroundStyle(Color.white.opacity(0.5)).lineLimit(1)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .pressable(scale: 0.985, tag: "video-\(video.videoId)", action: onPlay)
    }
}
