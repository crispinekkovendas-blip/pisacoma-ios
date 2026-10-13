import Foundation

/// One URLSession for the live bits (YouTube feed, Wiktionary, the announcements sheet) and the content downloads.
enum Http {
    /// Tests flip this to simulate no signal; every call then fails fast.
    nonisolated(unsafe) static var forceOffline = false

    struct Status: Error, Equatable { let code: Int }
    struct Offline: Error {}

    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 120
        c.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 Pisacoma-iOS"]
        return URLSession(configuration: c)
    }()

    /// GET → body text; throws `Status` on non-2xx and a URLError on network trouble.
    static func get(_ url: String) async throws -> String {
        let data = try await bytes(url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// GET → body bytes.
    static func bytes(_ url: String) async throws -> Data {
        if forceOffline { throw Offline() }
        guard let u = URL(string: url) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: u)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { throw Status(code: http.statusCode) }
        return data
    }
}
