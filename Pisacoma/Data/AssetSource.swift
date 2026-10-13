import Foundation

enum AssetError: Error, Equatable {
    case notFound(String)
}

/// Where content is read from: the bundle's `Content/` folder, a folder on disk, or the content store.
protocol AssetSource: AnyObject, Sendable {
    func read(_ path: String) async throws -> Data
    func exists(_ path: String) async -> Bool
}

extension AssetSource {
    func readText(_ path: String) async throws -> String {
        let data = try await read(path)
        guard let s = String(data: data, encoding: .utf8) else { throw AssetError.notFound(path) }
        return s
    }
}

/// Files under a root folder (the app bundle's `Content/`, or any directory in tests).
final class FileAssetSource: AssetSource, @unchecked Sendable {
    let root: URL
    init(root: URL) { self.root = root }

    /// The app bundle's `Content/` folder.
    static func bundled(_ bundle: Bundle = .main) -> FileAssetSource {
        FileAssetSource(root: bundle.resourceURL!.appendingPathComponent("Content"))
    }

    func url(_ path: String) -> URL { root.appendingPathComponent(path) }

    func read(_ path: String) async throws -> Data {
        let u = url(path)
        guard FileManager.default.fileExists(atPath: u.path) else { throw AssetError.notFound(path) }
        return try Data(contentsOf: u)
    }

    func exists(_ path: String) async -> Bool {
        var dir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url(path).path, isDirectory: &dir) && !dir.boolValue
    }
}

/// Several sources layered: the first one that has the path answers.
final class CompositeAssetSource: AssetSource, @unchecked Sendable {
    let sources: [AssetSource]
    init(_ sources: [AssetSource]) { self.sources = sources }

    func read(_ path: String) async throws -> Data {
        for s in sources {
            if await s.exists(path) { return try await s.read(path) }
        }
        throw AssetError.notFound(path)
    }

    func exists(_ path: String) async -> Bool {
        for s in sources {
            if await s.exists(path) { return true }
        }
        return false
    }
}
