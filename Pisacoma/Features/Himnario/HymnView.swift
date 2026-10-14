import SwiftUI

/// The site's /himnario/<variant>/<n>: crumbs, numeral + title, tools, audio, the typeset lyrics, pager.
struct HymnView: View {
    let variant: String
    let number: Int
    @EnvironmentObject private var router: Router
    @StateObject private var model: HymnModel
    @ObservedObject private var player = HymnPlayer.shared
    @State private var projecting = false

    init(variant: String, number: Int) {
        self.variant = variant
        self.number = number
        _model = StateObject(wrappedValue: HymnModel(app: AppModel.shared, variant: variant, number: number))
    }

    var body: some View {
        switch model.state {
        case .loading:
            Color.clear
        case .notFound:
            VStack(alignment: .leading, spacing: 12) {
                Text("Himno no encontrado").font(Fonts.fraunces(24)).foregroundStyle(Tokens.inkDeep)
                Text("← Volver al himnario").font(Fonts.inter(15)).foregroundStyle(Tokens.sage).pressable { router.go(.himnario) }
                Spacer()
            }
            .padding(20)
        case let .ready(h, slides, hasNext):
            body(h, slides: slides, hasNext: hasNext)
        }
    }

    private func body(_ h: Hymn, slides: [ProjectorSlide], hasNext: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text("HIMNARIO").font(Fonts.inter(11, weight: .semibold)).tracking(2.2).foregroundStyle(Tokens.sage).pressable(scale: 0.98) { router.go(.himnario) }
                    Text("/").font(Fonts.inter(11)).foregroundStyle(Tokens.sageText.opacity(0.5))
                    Text(h.variant.label.uppercased()).font(Fonts.inter(11, weight: .semibold)).tracking(2.2).foregroundStyle(Tokens.sageText).lineLimit(1)
                }
                .padding(.top, 36).padding(.bottom, 22)
                HStack(spacing: 18) {
                    Text(String(h.number)).font(Fonts.fraunces(48, weight: .heavy, italic: true)).tracking(-0.04 * 48).foregroundStyle(Ochre.numeral).accessibilityIdentifier("hymn-number")
                    VStack(alignment: .leading, spacing: 6) {
                        Text(h.title).font(Fonts.fraunces(24, weight: .semibold)).tracking(-0.022 * 24).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true)
                        if let ref = h.bibleReference { Text(ref).font(Fonts.fraunces(15.2, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText) }
                    }
                }
                .padding(.top, 16).padding(.bottom, 22)
                Hairline(alpha: 0.18)
                Spacer().frame(height: 16)
                HStack(spacing: 10) {
                    ToolPill(icon: "ic_project", label: "Proyectar", tag: "hymn-project") { projecting = true }
                    ShareButton(title: "#\(h.number) \(h.title)", text: "Himno \(h.number) · \(h.title) — \(h.variant.label)", path: "/himnario/\(h.variant.slug)/\(h.number)/")
                }
                Spacer().frame(height: 24)
                if let yt = h.ytId {
                    YouTubeEmbed(videoId: yt)
                    Spacer().frame(height: 30)
                } else if h.mp3Url != nil {
                    AudioCard(tracks: Self.tracks(h), state: player.state, onToggle: { t in player.play(mediaId: t.mediaId, title: t.title, url: t.url) }, onSeek: { player.seekTo($0) })
                    Spacer().frame(height: 32)
                }
                // .lyrics — .verse rows: numeral column + lines; the chorus is italic with a 2pt ochre rule
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(h.blocks.enumerated()), id: \.offset) { i, b in
                        HStack(alignment: .top, spacing: 14) {
                            if b.isChorus {
                                Text("CORO").font(Fonts.inter(12.5, weight: .bold)).tracking(2.4).foregroundStyle(Ochre.label).frame(width: 28, alignment: .trailing).padding(.top, 9)
                                Rectangle().fill(Color(hex: 0xB8924F, alpha: 0.55)).frame(width: 2)
                            } else {
                                Text(String(b.stanzaNumber ?? (i + 1))).font(Fonts.fraunces(18.4, weight: .bold, italic: true)).foregroundStyle(Ochre.label).frame(width: 28, alignment: .trailing).padding(.top, 4)
                            }
                            Text(b.lines.joined(separator: "\n"))
                                .font(Fonts.fraunces(17.3, weight: .regular, italic: b.isChorus))
                                .lineSpacing(10)
                                .foregroundStyle(b.isChorus ? Tokens.forest : Tokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 24)
                        if i < h.blocks.count - 1 {
                            Rectangle().fill(Tokens.sageA(0.18)).frame(height: 1)
                            Spacer().frame(height: 28)
                        }
                    }
                }
                .accessibilityIdentifier("hymn-lyrics")
                Spacer().frame(height: 50)
                Hairline(alpha: 0.18)
                Spacer().frame(height: 26)
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    if h.number > 1 { PagerPill(label: "← \(h.number - 1)", tag: "hymn-prev") { router.go(.hymn(variant: h.variant.slug, number: h.number - 1)) } }
                    PagerPill(label: "Índice", tag: "hymn-index", ochre: true) { router.go(.himnario) }
                    if hasNext { PagerPill(label: "\(h.number + 1) →", tag: "hymn-next") { router.go(.hymn(variant: h.variant.slug, number: h.number + 1)) } }
                    Spacer(minLength: 0)
                }
                Spacer().frame(height: 70)
            }
            .padding(.horizontal, 20)
            SiteFooter()
        }
        .accessibilityIdentifier("hymn-page")
        .fullScreenCover(isPresented: $projecting) {
            HymnProjectorView(number: h.number, title: h.title, bibleRef: h.bibleReference, slides: slides) { projecting = false }
        }
    }
}

extension HymnView {
    static func tracks(_ h: Hymn) -> [AudioTrack] {
        var tracks = [AudioTrack(mediaId: AudioUrls.mediaId(h, instrumental: false), label: "Vocal", title: AudioUrls.title(h, instrumental: false), url: AudioUrls.streamUrl(h, instrumental: false)!)]
        if h.mp3UrlInstr != nil {
            tracks.append(AudioTrack(mediaId: AudioUrls.mediaId(h, instrumental: true), label: "Instrumental", title: AudioUrls.title(h, instrumental: true), url: AudioUrls.streamUrl(h, instrumental: true)!))
        }
        return tracks
    }
}

private struct PagerPill: View {
    let label: String
    let tag: String
    var ochre = false
    let action: () -> Void
    var body: some View {
        Text(label).font(Fonts.inter(13, weight: .semibold)).foregroundStyle(ochre ? Ochre.label : Tokens.forest)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(Capsule().fill(Color.white.opacity(0.5)))
            .overlay(Capsule().stroke(ochre ? Color(hex: 0xB8924F, alpha: 0.4) : Tokens.sageA(0.24), lineWidth: 1))
            .pressable(scale: 0.97, tag: tag, action: action)
    }
}
