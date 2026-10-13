import Foundation

/// Hymn audio streams through the site's /api/audio proxy, built exactly as the hymn page does.
enum AudioUrls {
    static let site = "https://quiz-qwik.vercel.app"
    static let proxy = "\(site)/api/audio?url="

    /// `encodeURIComponent` semantics.
    static func proxied(_ mp3: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return proxy + (mp3.addingPercentEncoding(withAllowedCharacters: allowed) ?? mp3)
    }

    static func mediaId(_ hymn: Hymn, instrumental: Bool) -> String { "\(hymn.variant.slug)-\(hymn.number)" + (instrumental ? "-instr" : "") }

    static func title(_ hymn: Hymn, instrumental: Bool) -> String { "\(hymn.number) · \(hymn.title)" + (instrumental ? " (instrumental)" : "") }

    static func streamUrl(_ hymn: Hymn, instrumental: Bool) -> String? {
        (instrumental ? hymn.mp3UrlInstr : hymn.mp3Url).map(proxied)
    }
}
