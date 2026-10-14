import Combine
import Foundation

struct VideoRowUi: Equatable, Identifiable {
    let key: String
    let label: String
    let num: String
    let videos: [TaggedVideo]
    var id: String { key }
}

struct VideosUi: Equatable {
    var videos: [TaggedVideo] = []
    var loading = true
    var offline = false
    var query = ""

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var results: [TaggedVideo] {
        guard isSearching else { return [] }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return videos.filter { $0.title.lowercased().contains(q) }
    }
    var hero: TaggedVideo? { videos.first { $0.hero } ?? videos.first }

    /// Site rows: «Añadidos recientemente», one per channel, one per category (only non-empty).
    var rows: [VideoRowUi] {
        var out = [VideoRowUi(key: "recientes", label: "Añadidos recientemente", num: "01", videos: Array(videos.prefix(24)))]
        var n = 2
        for ch in VideoCatalog.channels {
            let vs = videos.filter { $0.tags.contains("channel:\(ch.key)") }
            if !vs.isEmpty { out.append(VideoRowUi(key: "channel:\(ch.key)", label: ch.label, num: String(format: "%02d", n), videos: vs)); n += 1 }
        }
        for c in VideoCatalog.cats {
            let vs = videos.filter { $0.tags.contains(c.key) }
            if !vs.isEmpty { out.append(VideoRowUi(key: c.key, label: c.label, num: String(format: "%02d", n), videos: vs)); n += 1 }
        }
        return out
    }
}

/**
 Loads the catalogue from the site's /videos/api/youtube (the four channels' RSS, merged and
 sorted there) and keeps the last good copy for 24 h so the screen opens offline.
 */
@MainActor
final class VideosModel: ObservableObject {
    @Published private(set) var state = VideosUi()
    private let userState: UserState

    init(userState: UserState) {
        self.userState = userState
        load()
    }

    func load() {
        state.loading = true
        state.offline = false
        Task {
            let cached = userState.string(UserState.Keys.videosCache)
            let cachedAt = userState.string(UserState.Keys.videosCacheAt).flatMap { Int64($0) } ?? 0
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            if let cached, cachedAt > now - 24 * 3_600_000 { show(cached); return }
            do {
                let body = try await Http.get(VideoCatalog.feedUrl)
                if !VideoCatalog.parseFeed(body).isEmpty {
                    userState.set(UserState.Keys.videosCache, body)
                    userState.set(UserState.Keys.videosCacheAt, String(now))
                }
                show(body)
            } catch {
                if let cached { show(cached) } else { state.loading = false; state.offline = true }
            }
        }
    }

    private func show(_ body: String) {
        var seen = Set<String>()
        let list = VideoCatalog.parseFeed(body).filter { !$0.videoId.isEmpty && seen.insert($0.videoId).inserted }.map(VideoCatalog.tagVideo)
        state.videos = list
        state.loading = false
        state.offline = list.isEmpty
    }

    func query(_ q: String) { state.query = q }
}
