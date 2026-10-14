import SwiftUI
import WebKit

/// m:ss for a duration in milliseconds.
func clockMs(_ ms: Int64) -> String {
    let s = max(0, ms / 1000)
    return "\(s / 60):" + String(format: "%02d", s % 60)
}

/**
 The hymn page's `.audio` card: a parchment card with one row per track («Vocal»,
 «Instrumental»), each a play/pause button, a scrub bar and the time.
 */
struct AudioCard: View {
    let tracks: [AudioTrack]
    let state: PlayerState
    let onToggle: (AudioTrack) -> Void
    let onSeek: (Int64) -> Void
    @State private var dragging: [String: Double] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tracks) { t in
                let current = state.mediaId == t.mediaId
                let dur = current ? state.durationMs : 0
                let pos = current ? state.positionMs : 0
                Eyebrow(t.label, Tokens.sage, size: 10.5, tracking: 2, weight: .bold)
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Tokens.forest)
                        IconView(name: current && state.isPlaying ? "ic_pause" : "ic_play", color: Tokens.cream).frame(width: 20, height: 20)
                    }
                    .frame(width: 44, height: 44)
                    .pressable(tag: "audio-toggle-\(t.mediaId)") { onToggle(t) }
                    .accessibilityLabel(current && state.isPlaying ? "Pausar" : "Reproducir")
                    Slider(
                        value: Binding(
                            get: { dragging[t.mediaId] ?? (dur > 0 ? Double(pos) / Double(dur) : 0) },
                            set: { dragging[t.mediaId] = $0 }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            if !editing, let v = dragging[t.mediaId] {
                                if dur > 0 { onSeek(Int64(v * Double(dur))) }
                                dragging[t.mediaId] = nil
                            }
                        }
                    )
                    .tint(Tokens.sage)
                    .disabled(!(current && dur > 0))
                    Text(current && state.isBuffering && dur == 0 ? "…" : "\(clockMs(pos)) / \(clockMs(dur))")
                        .font(Fonts.inter(11.5)).foregroundStyle(Tokens.sageText).frame(width: 74, alignment: .leading)
                }
                .padding(.bottom, 6)
            }
            if let e = state.error { Text(e).font(Fonts.inter(12.5)).foregroundStyle(Color(hex: 0x8A3A2A)).padding(.top, 2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(hex: 0xFBF9EF), Color(hex: 0xECE9D6)], startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.sageA(0.20), lineWidth: 1))
        .accessibilityIdentifier("audio-card")
    }
}

/**
 The hymn page's `.yt` box for the Novo Hinário (NHA): YouTube's own IFrame player in a 16:9 box
 capped at 160 pt, with the site's forest gradient behind it.
 */
struct YouTubeEmbed: View {
    let videoId: String
    var autoplay = false

    var body: some View {
        YouTubeWebView(videoId: videoId, autoplay: autoplay)
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxHeight: 160)
            .background(LinearGradient(colors: [Tokens.forest, Tokens.inkDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.sageA(0.22), lineWidth: 1))
            .accessibilityIdentifier("youtube-\(videoId)")
    }
}

/// YouTube IFrame player (YouTube requires its embed) with inline playback and the site's options.
struct YouTubeWebView: UIViewRepresentable {
    let videoId: String
    var autoplay = false

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = autoplay ? [] : [.all]
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body{margin:0;background:transparent;height:100%}iframe{width:100%;height:100%;border:0}</style></head>
        <body><iframe src="https://www.youtube.com/embed/\(videoId)?playsinline=1&controls=1&rel=0&modestbranding=1&autoplay=\(autoplay ? 1 : 0)&enablejsapi=1" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://quiz-qwik.vercel.app"))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
