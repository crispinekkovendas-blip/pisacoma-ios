import Combine
import SwiftUI
import WebKit

private let speeds: [Double] = [0.75, 1, 1.25, 1.5, 2]

/// The state the YouTube IFrame player reports through its JS bridge.
@MainActor
final class YouTubeController: ObservableObject {
    @Published var playing = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    weak var web: WKWebView?

    func js(_ s: String) { web?.evaluateJavaScript(s, completionHandler: nil) }
    func play() { js("player && player.playVideo()") }
    func pause() { js("player && player.pauseVideo()") }
    func seek(_ t: Double) { js("player && player.seekTo(\(max(0, t)), true)"); current = max(0, t) }
    func rate(_ r: Double) { js("player && player.setPlaybackRate(\(r))") }
    func mute(_ m: Bool) { js(m ? "player && player.mute()" : "player && player.unMute()") }
}

/// YouTube's IFrame player (required by YouTube) with no native controls, driven through the JS API.
struct YouTubePlayerBridge: UIViewRepresentable {
    let videoId: String
    @ObservedObject var controller: YouTubeController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "player")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        controller.web = web
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body{margin:0;background:#000;height:100%;overflow:hidden}#p{width:100%;height:100%}</style></head>
        <body><div id="p"></div>
        <script>
          var tag=document.createElement('script');tag.src='https://www.youtube.com/iframe_api';document.head.appendChild(tag);
          var player, timer;
          function post(m){window.webkit.messageHandlers.player.postMessage(m)}
          function onYouTubeIframeAPIReady(){
            player=new YT.Player('p',{videoId:'\(videoId)',playerVars:{playsinline:1,controls:0,rel:0,iv_load_policy:3,cc_load_policy:0,modestbranding:1,autoplay:1,origin:'https://quiz-qwik.vercel.app'},
              events:{onReady:function(){player.playVideo();timer=setInterval(function(){try{post({t:player.getCurrentTime(),d:player.getDuration()})}catch(e){}},500)},
                      onStateChange:function(e){post({s:e.data})}}});
          }
        </script></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://quiz-qwik.vercel.app"))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "player")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let controller: YouTubeController
        init(controller: YouTubeController) { self.controller = controller }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let m = message.body as? [String: Any] else { return }
            Task { @MainActor in
                if let s = m["s"] as? Int { controller.playing = s == 1 }
                if let t = m["t"] as? Double { controller.current = t }
                if let d = m["d"] as? Double, d > 0 { controller.duration = d }
            }
        }
    }
}

/**
 The site's CustomPlayer: YouTube's IFrame player under the app's own HBO-style controls —
 play/pause, ±10 s, scrub bar with time, speed, mute, fullscreen — that hide after 3.2 s.
 The catalogue list of more videos follows below.
 */
struct VideoPlayerView: View {
    let videoId: String
    @EnvironmentObject private var router: Router
    @Environment(\.openURL) private var openURL
    @StateObject private var model: VideosModel
    @StateObject private var player = YouTubeController()
    @State private var muted = false
    @State private var speed: Double = 1
    @State private var showSpeed = false
    @State private var showCtrl = true
    @State private var fullscreen = false
    @State private var dragging: Double? = nil
    @State private var hideTask: Task<Void, Never>? = nil

    init(videoId: String) {
        self.videoId = videoId
        _model = StateObject(wrappedValue: VideosModel(userState: AppModel.shared.userState))
    }

    private var video: TaggedVideo? { model.state.videos.first { $0.videoId == videoId } }

    private func reveal() {
        showCtrl = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled, player.playing { showCtrl = false }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                stage.aspectRatio(16 / 9, contentMode: .fit)
                details
            }
        }
        .background(Color.black)
        .uiId("video-page")
        .onAppear { reveal() }
        .fullScreenCover(isPresented: $fullscreen) {
            stage.background(Color.black.ignoresSafeArea())
        }
    }

    private var stage: some View {
        ZStack {
            Color.black
            YouTubePlayerBridge(videoId: videoId, controller: player)
            Color.clear.contentShape(Rectangle()).onTapGesture { if showCtrl { showCtrl = false } else { reveal() } }
            if showCtrl { controls }
        }
        .uiId("player")
    }

    private var controls: some View {
        ZStack {
            LinearGradient(stops: [.init(color: Color.black.opacity(0.6), location: 0), .init(color: .clear, location: 0.4), .init(color: .clear, location: 0.7), .init(color: Color.black.opacity(0.8), location: 1)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack {
                HStack(spacing: 8) {
                    IconBtn(icon: "ic_nav_close", label: "Cerrar", tag: "player-close") { if fullscreen { fullscreen = false } else { router.go(.videos) } }
                    Text(video?.title ?? "").font(Fonts.inter(14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                }
                .padding(10)
                Spacer()
                HStack(spacing: 34) {
                    IconBtn(icon: "ic_back", label: "Retroceder 10s", tag: "player-back10", big: true) { player.seek(player.current - 10); reveal() }
                    ZStack {
                        Circle().fill(Color.white.opacity(0.9))
                        IconView(name: player.playing ? "ic_pause" : "ic_play", color: .black).frame(width: 28, height: 28)
                    }
                    .frame(width: 64, height: 64)
                    .pressable(scale: 0.95, tag: "player-toggle") { if player.playing { player.pause() } else { player.play() }; reveal() }
                    .accessibilityLabel(player.playing ? "Pausar" : "Reproducir")
                    IconBtn(icon: "ic_nav_arrow", label: "Avanzar 10s", tag: "player-fwd10", big: true) { player.seek(min(player.current + 10, player.duration > 0 ? player.duration : player.current + 10)); reveal() }
                }
                Spacer()
                VStack(spacing: 2) {
                    Slider(
                        value: Binding(get: { dragging ?? (player.duration > 0 ? min(1, max(0, player.current / player.duration)) : 0) }, set: { dragging = $0; reveal() }),
                        in: 0...1,
                        onEditingChanged: { editing in
                            if !editing, let v = dragging { if player.duration > 0 { player.seek(v * player.duration) }; dragging = nil }
                        }
                    )
                    .tint(Tokens.accent)
                    .uiId("player-seek")
                    HStack(spacing: 6) {
                        IconBtn(icon: player.playing ? "ic_pause" : "ic_play", label: player.playing ? "Pausar" : "Reproducir", tag: "player-toggle-small") { if player.playing { player.pause() } else { player.play() }; reveal() }
                        Text(VideoCatalog.fmtTime(player.current) + (player.duration > 0 ? " / " + VideoCatalog.fmtTime(player.duration) : "")).font(Fonts.inter(12)).foregroundStyle(.white).accessibilityIdentifier("player-time")
                        Spacer()
                        ZStack(alignment: .bottomTrailing) {
                            Text(speed == 1 ? "1×" : "\(speedLabel(speed))×").font(Fonts.inter(13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .pressable(tag: "player-speed") { showSpeed.toggle(); reveal() }
                            if showSpeed {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(speeds, id: \.self) { sp in
                                        Text(sp == 1 ? "Normal" : "\(speedLabel(sp))×").font(Fonts.inter(13)).foregroundStyle(sp == speed ? Tokens.accentLight : .white)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .pressable { speed = sp; player.rate(sp); showSpeed = false; reveal() }
                                    }
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x161B22, alpha: 0.95)))
                                .offset(y: -34)
                            }
                        }
                        IconBtn(icon: muted ? "ic_minus" : "ic_plus", label: muted ? "Activar sonido" : "Silenciar", tag: "player-mute") { muted.toggle(); player.mute(muted); reveal() }
                        IconBtn(icon: "ic_fullscreen", label: "Pantalla completa", tag: "player-fullscreen") { fullscreen.toggle(); reveal() }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
    }

    private func speedLabel(_ s: Double) -> String { s == s.rounded() ? String(Int(s)) : String(s) }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(video?.title ?? "").font(Fonts.playfair(20, weight: .semibold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 6)
            Text(VideoCatalog.channelName + (video?.published.map { " · \(VideoCatalog.relTimeEsIso($0))" } ?? "")).font(Fonts.inter(12.5)).foregroundStyle(Color.white.opacity(0.6))
            Spacer().frame(height: 12)
            HStack(spacing: 10) {
                Text("Abrir en YouTube").font(Fonts.inter(13, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                    .pressable(scale: 0.97) { openURL(URL(string: "https://www.youtube.com/watch?v=\(videoId)")!) }
                Text("Compartir").font(Fonts.inter(13, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                    .pressable(scale: 0.97) {
                        let vc = UIActivityViewController(activityItems: ["\(video?.title ?? "")\n\(AudioUrls.site)/videos/\(videoId)"], applicationActivities: nil)
                        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.rootViewController?.topMost.present(vc, animated: true)
                    }
            }
            Spacer().frame(height: 22)
            Text("Más videos").font(Fonts.inter(15, weight: .semibold)).foregroundStyle(.white)
            Spacer().frame(height: 10)
            ForEach(model.state.videos.filter { $0.videoId != videoId }.prefix(12)) { v in
                HStack(spacing: 10) {
                    Thumb(videoId: v.videoId).frame(width: 128, height: 72).clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(v.title).font(Fonts.inter(13)).lineSpacing(3).foregroundStyle(Color.white.opacity(0.85)).lineLimit(3)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .pressable(scale: 0.98) { router.go(.video(id: v.videoId)) }
            }
        }
        .padding(16)
        .background(Tokens.bg)
    }
}

private struct IconBtn: View {
    let icon: String
    let label: String
    let tag: String
    var big = false
    let action: () -> Void
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.2))
            IconView(name: icon, color: .white).frame(width: big ? 22 : 18, height: big ? 22 : 18)
        }
        .frame(width: big ? 48 : 38, height: big ? 48 : 38)
        .pressable(tag: tag, action: action)
        .accessibilityLabel(label)
    }
}
