import Combine
import Foundation

/// A file that is neither bundled nor stored, asked for while offline.
struct ContentMissing: Error, Equatable {
    let path: String
}

/// A download whose body was not the size the manifest expects.
struct ShortBody: Error, Equatable {
    let path: String
    let got: Int
    let expected: Int64
}

/**
 Every content read goes through here: the bundle's `Content/` first, then the files already saved
 under `dir` (Application Support/content), then the network. What is fetched is kept on disk
 unless the mode is «Mantener solo en línea». A fetch that fails offline sets `missing` so the
 chrome can show one notice, and throws `ContentMissing`.
 */
final class ContentStore: AssetSource, ObservableObject, @unchecked Sendable {
    let bundled: AssetSource
    let dir: URL
    let manifest: Manifest
    private let mode: () -> ContentMode?
    private let fetch: (String) async throws -> Data

    /// The last path that could not be read offline; cleared by the notice's buttons. Main thread.
    @Published var missing: String?

    init(bundled: AssetSource, dir: URL, manifest: Manifest, mode: @escaping () -> ContentMode?, fetch: @escaping (String) async throws -> Data) {
        self.bundled = bundled
        self.dir = dir
        self.manifest = manifest
        self.mode = mode
        self.fetch = fetch
    }

    func file(_ path: String) -> URL { dir.appendingPathComponent(path) }

    private func fileSize(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    /// On disk with the size the manifest expects — so a new app version's manifest makes changed files download again.
    func isStored(_ path: String) -> Bool {
        guard let size = fileSize(file(path)) else { return false }
        guard let expected = manifest.byPath(path)?.bytes else { return true }
        return size == expected
    }

    private func storedFiles() -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        var out: [URL] = []
        for case let u as URL in e {
            if (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true, !u.lastPathComponent.hasSuffix(".part") { out.append(u) }
        }
        return out
    }

    func storedBytes() -> Int64 { storedFiles().reduce(0) { $0 + (fileSize($1) ?? 0) } }
    func storedCount() -> Int { storedFiles().count }

    func exists(_ path: String) async -> Bool {
        if await bundled.exists(path) { return true }
        return isStored(path) || manifest.byPath(path) != nil
    }

    func read(_ path: String) async throws -> Data {
        if await bundled.exists(path) { return try await bundled.read(path) }
        let f = file(path)
        if isStored(path) { return try Data(contentsOf: f) }
        let bytes = try await fetchVerified(path, report: true)
        if mode()?.persists != false { try writeAtomic(f, bytes) }
        return bytes
    }

    /// Saves one file for later; a no-op when it is already stored. Throws on network trouble
    /// without raising the notice: a background download failing is not the reader's problem.
    func download(_ path: String) async throws {
        if isStored(path) { return }
        try writeAtomic(file(path), try await fetchVerified(path, report: false))
    }

    /// Deletes every stored file (the mode is kept).
    func clear() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func fetchVerified(_ path: String, report: Bool) async throws -> Data {
        let bytes: Data
        do {
            bytes = try await fetch(path)
        } catch {
            if report {
                let p = path
                DispatchQueue.main.async { self.missing = p }
            }
            throw ContentMissing(path: path)
        }
        if let expected = manifest.byPath(path)?.bytes, Int64(bytes.count) != expected {
            throw ShortBody(path: path, got: bytes.count, expected: expected)
        }
        return bytes
    }

    private func writeAtomic(_ target: URL, _ bytes: Data) throws {
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let part = URL(fileURLWithPath: target.path + ".part")
        try bytes.write(to: part)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        try FileManager.default.moveItem(at: part, to: target)
    }
}
