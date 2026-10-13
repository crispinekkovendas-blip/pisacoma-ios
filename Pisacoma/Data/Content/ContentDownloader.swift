import Combine
import Foundation

enum DownloadState: Equatable {
    case idle
    case running(doneFiles: Int, totalFiles: Int, doneBytes: Int64, totalBytes: Int64, failed: Int)
    case done(totalBytes: Int64)
    case error(failed: Int, totalFiles: Int)

    var isRunning: Bool { if case .running = self { return true } else { return false } }
}

/**
 Downloads the packs a mode asks for, one file after another, skipping what is already stored
 and retrying each file up to three times. `onComplete` gets `true` when every file is on disk.
 Lives on the app model, so a screen change or rotation does not touch it.
 */
final class ContentDownloader: ObservableObject, @unchecked Sendable {
    static let attempts = 3

    private let store: ContentStore
    private let onComplete: (Bool) -> Void
    private let lock = NSLock()
    private var running = false

    /// Updated on the main thread.
    @Published private(set) var state: DownloadState = .idle

    init(store: ContentStore, onComplete: @escaping (Bool) -> Void = { _ in }) {
        self.store = store
        self.onComplete = onComplete
    }

    /// The files of `mode` that are not stored yet.
    func missingFor(_ mode: ContentMode) -> [ContentFile] {
        store.manifest.filesFor(mode).filter { !store.isStored($0.path) }
    }

    private func publish(_ s: DownloadState) {
        if Thread.isMainThread { state = s } else { DispatchQueue.main.sync { self.state = s } }
    }

    /// Starts the download; nil when nothing is missing (state becomes done) or one is already running.
    @discardableResult
    func start(_ mode: ContentMode) -> Task<Void, Never>? {
        lock.lock()
        if running { lock.unlock(); return nil }
        let all = store.manifest.filesFor(mode)
        let todo = all.filter { !store.isStored($0.path) }
        let totalBytes = all.reduce(0) { $0 + $1.bytes }
        if todo.isEmpty {
            lock.unlock()
            publish(.done(totalBytes: totalBytes))
            onComplete(true)
            return nil
        }
        running = true
        lock.unlock()
        let doneBefore = all.count - todo.count
        let bytesBefore = totalBytes - todo.reduce(0) { $0 + $1.bytes }
        publish(.running(doneFiles: doneBefore, totalFiles: all.count, doneBytes: bytesBefore, totalBytes: totalBytes, failed: 0))
        return Task.detached(priority: .utility) { [self] in
            var done = doneBefore
            var bytes = bytesBefore
            var failed = 0
            for f in todo {
                if await fetchWithRetries(f.path) { done += 1; bytes += f.bytes } else { failed += 1 }
                publish(.running(doneFiles: done, totalFiles: all.count, doneBytes: bytes, totalBytes: totalBytes, failed: failed))
            }
            // The pending flag is settled before the final state is published.
            onComplete(failed == 0)
            publish(failed == 0 ? .done(totalBytes: totalBytes) : .error(failed: failed, totalFiles: all.count))
            lock.lock(); running = false; lock.unlock()
        }
    }

    private func fetchWithRetries(_ path: String) async -> Bool {
        for _ in 0..<Self.attempts {
            do {
                try await store.download(path)
                return true
            } catch {
                continue
            }
        }
        return false
    }
}
