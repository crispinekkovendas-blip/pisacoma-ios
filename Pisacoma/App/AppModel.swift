import Foundation
import SwiftUI

/// The app's single set of services: the content store and downloader, the repositories and the user state.
@MainActor
final class AppModel: ObservableObject {
    static let contentBaseUrl = "https://raw.githubusercontent.com/crispinekkovendas-blip/pisacoma-android/main/content/"
    static let shared = AppModel()

    let userState: UserState
    let content: ContentStore
    let downloader: ContentDownloader
    let hymns: HymnRepository
    let bible: BibleRepository
    let egw: EgwRepository
    let quarterly: QuarterlyRepository
    let quizzes: QuizRepository
    let church: ChurchRepository
    let search: SearchRepository

    /// Set before the first screen: nil until the phone has chosen what to keep.
    var contentMode: ContentMode? { ContentMode.of(userState.string(UserState.Keys.contentMode)) }

    init(userState: UserState = UserState(), bundle: Bundle = .main, dir: URL? = nil, fetch: ((String) async throws -> Data)? = nil) {
        self.userState = userState
        let manifestUrl = bundle.resourceURL!.appendingPathComponent("Content/manifest.json")
        let manifest = (try? Manifest.parse(try Data(contentsOf: manifestUrl))) ?? Manifest()
        let storeDir = dir ?? Self.defaultDir()
        let fetcher = fetch ?? { path in try await Http.bytes(Self.contentBaseUrl + path) }
        let us = userState
        let store = ContentStore(bundled: FileAssetSource.bundled(bundle), dir: storeDir, manifest: manifest, mode: { ContentMode.of(us.string(UserState.Keys.contentMode)) }, fetch: fetcher)
        content = store
        downloader = ContentDownloader(store: store) { ok in us.set(UserState.Keys.contentPending, !ok) }
        hymns = HymnRepository(store)
        bible = BibleRepository(store)
        egw = EgwRepository(store)
        quarterly = QuarterlyRepository(store)
        quizzes = QuizRepository(store)
        church = ChurchRepository(store)
        search = SearchRepository(store)
        Self.applyLaunchArguments(userState: us, store: store, bundle: bundle)
        // A download interrupted by the app dying resumes on the next open.
        if let mode = contentMode, mode.downloads, us.bool(UserState.Keys.contentPending) { downloader.start(mode) }
    }

    static func defaultDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("content")
    }

    /// UI-test hooks (`-seedContent`, `-wipeContent`, `-mode todo`, `-firstRun`, `-forceOffline`), DEBUG only.
    private static func applyLaunchArguments(userState: UserState, store: ContentStore, bundle: Bundle) {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-wipeContent") { store.clear() }
        if args.contains("-seedContent") {
            // The UI-test host carries the downloadable content as `TestContent/` (see project.yml).
            let src = bundle.resourceURL!.appendingPathComponent("TestContent")
            for f in store.manifest.files where !store.isStored(f.path) {
                let from = src.appendingPathComponent(f.path)
                let to = store.file(f.path)
                try? FileManager.default.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: to)
                try? FileManager.default.copyItem(at: from, to: to)
            }
        }
        if let i = args.firstIndex(of: "-mode"), i + 1 < args.count {
            userState.set(UserState.Keys.contentMode, args[i + 1])
            userState.set(UserState.Keys.contentPending, false)
        }
        if args.contains("-firstRun") { userState.set(UserState.Keys.contentMode, nil) }
        if args.contains("-clearUserState") {
            for k in userState.keysWithPrefix("") where k != UserState.Keys.contentMode && k != UserState.Keys.contentPending { userState.set(k, nil) }
        }
        if args.contains("-forceOffline") { Http.forceOffline = true }
        #endif
    }
}
