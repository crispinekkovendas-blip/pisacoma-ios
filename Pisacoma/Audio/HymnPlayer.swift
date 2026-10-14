import AVFoundation
import Combine
import Foundation
import MediaPlayer

struct PlayerState: Equatable {
    var mediaId: String? = nil
    var isPlaying = false
    var isBuffering = false
    var positionMs: Int64 = 0
    var durationMs: Int64 = 0
    var error: String? = nil
}

struct AudioTrack: Equatable, Identifiable {
    let mediaId: String
    let label: String
    let title: String
    let url: String
    var id: String { mediaId }
}

/**
 The one AVPlayer for hymn audio (Android HymnPlaybackService + PlayerConnection): background
 audio session, now-playing info and lock-screen controls, one state the screens observe.
 */
@MainActor
final class HymnPlayer: ObservableObject {
    static let shared = HymnPlayer()

    @Published private(set) var state = PlayerState()
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var currentItem: AVPlayerItem?
    private var currentTitle = ""
    private var bag: Set<AnyCancellable> = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            Task { @MainActor in self?.tick(t) }
        }
        rateObserver = player.observe(\.rate, options: [.new]) { [weak self] p, _ in
            Task { @MainActor in
                guard let self else { return }
                self.state.isPlaying = p.rate > 0
                self.updateNowPlaying()
            }
        }
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime).sink { [weak self] n in
            Task { @MainActor in
                guard let self, (n.object as? AVPlayerItem) === self.currentItem else { return }
                self.player.seek(to: .zero)
                self.state.isPlaying = false
                self.state.positionMs = 0
            }
        }.store(in: &bag)
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        cc.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        cc.changePlaybackPositionCommand.addTarget { [weak self] e in
            if let e = e as? MPChangePlaybackPositionCommandEvent { Task { @MainActor in self?.seekTo(Int64(e.positionTime * 1000)) } }
            return .success
        }
    }

    private func tick(_ t: CMTime) {
        guard currentItem != nil else { return }
        state.positionMs = max(0, Int64(t.seconds.isFinite ? t.seconds * 1000 : 0))
        if let d = currentItem?.duration, d.seconds.isFinite, d.seconds > 0 { state.durationMs = Int64(d.seconds * 1000) }
        state.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
    }

    /// Plays `url` as `mediaId`, replacing whatever was playing; toggles when it is already current.
    func play(mediaId: String, title: String, url: String) {
        if state.mediaId == mediaId, currentItem != nil {
            toggle()
            return
        }
        guard let u = URL(string: url) else { state.error = "No se pudo cargar el audio"; return }
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: u)
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] it, _ in
            Task { @MainActor in
                guard let self else { return }
                if it.status == .failed { self.state.error = "No se pudo cargar el audio"; self.state.isPlaying = false; self.state.isBuffering = false }
                if it.status == .readyToPlay, it.duration.seconds.isFinite { self.state.durationMs = Int64(it.duration.seconds * 1000); self.updateNowPlaying() }
            }
        }
        currentItem = item
        currentTitle = title
        player.replaceCurrentItem(with: item)
        player.play()
        state = PlayerState(mediaId: mediaId, isPlaying: true, isBuffering: true, positionMs: 0, durationMs: 0, error: nil)
        updateNowPlaying()
    }

    func toggle() { if player.rate > 0 { pause() } else { resume() } }
    func pause() { player.pause(); state.isPlaying = false }
    func resume() { guard currentItem != nil else { return }; try? AVAudioSession.sharedInstance().setActive(true); player.play(); state.isPlaying = true }

    func seekTo(_ ms: Int64) {
        player.seek(to: CMTime(seconds: Double(ms) / 1000, preferredTimescale: 600))
        state.positionMs = ms
        updateNowPlaying()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentItem = nil
        state = PlayerState()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func updateNowPlaying() {
        guard currentItem != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPMediaItemPropertyArtist: "Himnario · Pisacoma",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(state.positionMs) / 1000,
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0,
        ]
        if state.durationMs > 0 { info[MPMediaItemPropertyPlaybackDuration] = Double(state.durationMs) / 1000 }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
