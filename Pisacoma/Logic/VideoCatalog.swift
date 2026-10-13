import Foundation

/// One video of the catalogue (site videos/data.ts VideoEntry).
struct VideoEntry: Codable, Equatable, Hashable {
    let videoId: String
    let title: String
    var published: String? = nil
    var tags: [String]? = nil
    var hero: Bool? = nil
    var channel: String? = nil
}

struct TaggedVideo: Equatable, Hashable, Identifiable {
    let entry: VideoEntry
    let tags: [String]
    var videoId: String { entry.videoId }
    var title: String { entry.title }
    var published: String? { entry.published }
    var hero: Bool { entry.hero == true }
    var id: String { entry.videoId }
}

struct Channel: Equatable { let key: String; let id: String; let label: String; let shortLabel: String }
struct Category { let key: String; let label: String; let regex: NSRegularExpression }

/// Port of the site's videos/data.ts: channels, categories, tagging, times, thumbnails, feed parsing.
enum VideoCatalog {
    static let channelName = "Iglesia Adventista del Séptimo Día — Pisacoma"
    static let feedUrl = "https://quiz-qwik.vercel.app/videos/api/youtube"

    static let channels = [
        Channel(key: "bullon", id: "UCzY9YOmZquSEERTbl_u-MSQ", label: "Pr. Alejandro Bullón", shortLabel: "Bullón"),
        Channel(key: "flores", id: "UCwFBSOeEwzF5hloXaUsvWyw", label: "Pr. Joel Flores", shortLabel: "Flores"),
        Channel(key: "sumtv", id: "UCFqRy7pWgY3Yii43GyjtAuA", label: "SUMtv Latino · Pr. Bohr", shortLabel: "SUMtv"),
        Channel(key: "lecciones", id: "UChboqca1Z0bIcoHQk5yGqnQ", label: "Lecciones Escuela Sabática", shortLabel: "Lecciones"),
    ]

    private static func re(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: [.caseInsensitive]) }

    static let cats = [
        Category(key: "sermones", label: "Sermones · Predicación", regex: re("serm[oó]n|predicac")),
        Category(key: "escuela_sabatica", label: "Escuela Sabática", regex: re("escuela sab[aá]tica|lecci[oó]n")),
        Category(key: "musica", label: "Música & Himnos", regex: re("m[uú]sica|himno|canto|coro|alabanza")),
        Category(key: "profecia", label: "Profecía", regex: re("profec[ií]a|apocalipsis|daniel")),
        Category(key: "salud_familia", label: "Salud & Familia", regex: re("salud|familia|hogar|matrimonio")),
        Category(key: "en_vivo", label: "En Vivo", regex: re("en vivo|directo|\\blive\\b")),
        Category(key: "juveniles", label: "Juveniles · JA", regex: re("j[oó]ven|juvenil|\\bja\\b")),
        Category(key: "ninos", label: "Niños", regex: re("ni[ñn]o|infantil")),
        Category(key: "egw", label: "Espíritu de Profecía", regex: re("elena|white|egw|esp[ií]ritu de profec")),
        Category(key: "pisacoma", label: "Pisacoma · Local", regex: re("pisacoma|chucuito|aimara|altiplano")),
    ]

    static func tagVideo(_ v: VideoEntry) -> TaggedVideo {
        let range = NSRange(location: 0, length: (v.title as NSString).length)
        let auto = cats.filter { $0.regex.firstMatch(in: v.title, range: range) != nil }.map { $0.key }
        let manual = v.tags ?? []
        let channel = v.channel.map { ["channel:\($0)"] } ?? []
        var seen = Set<String>()
        let all = (auto + manual + channel).filter { seen.insert($0).inserted }
        return TaggedVideo(entry: v, tags: all)
    }

    /// "1:15" for seconds (site fmtTime).
    static func fmtTime(_ s: Double) -> String {
        if s.isNaN || s <= 0 { return "0:00" }
        let m = Int(s / 60)
        let ss = Int(s.truncatingRemainder(dividingBy: 60))
        return "\(m):" + String(format: "%02d", ss)
    }

    static let thumbSizes = ["maxresdefault", "hqdefault", "sddefault", "mqdefault", "default"]
    static func thumb(_ videoId: String, _ size: String = "hqdefault") -> String { "https://i.ytimg.com/vi/\(videoId)/\(size).jpg" }

    /// Intl.RelativeTimeFormat("es", { numeric: "auto" }) over the site's thresholds.
    static func relTimeEs(_ published: Int64?, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> String {
        guard let published else { return "" }
        let diff = max(0, Int64((Double(now - published) / 1000.0).rounded()))
        if diff < 60 { return diff == 0 ? "ahora" : plural(diff, "segundo", "segundos") }
        if diff < 3600 { let v = Int64((Double(diff) / 60).rounded()); return plural(v, "minuto", "minutos") }
        if diff < 86400 { let v = Int64((Double(diff) / 3600).rounded()); return plural(v, "hora", "horas") }
        if diff < 86400 * 30 {
            let v = Int64((Double(diff) / 86400).rounded())
            if v == 1 { return "ayer" }
            if v == 2 { return "anteayer" }
            return "hace \(v) días"
        }
        if diff < 86400 * 365 {
            let v = Int64((Double(diff) / (86400.0 * 30)).rounded())
            return v == 1 ? "el mes pasado" : "hace \(v) meses"
        }
        let v = Int64((Double(diff) / (86400.0 * 365)).rounded())
        return v == 1 ? "el año pasado" : "hace \(v) años"
    }

    private static func plural(_ v: Int64, _ one: String, _ many: String) -> String { "hace \(v) \(v == 1 ? one : many)" }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func relTimeEsIso(_ isoString: String?, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> String {
        guard let isoString, let d = iso.date(from: isoString) ?? isoFractional.date(from: isoString) else { return relTimeEs(nil, now: now) }
        return relTimeEs(Int64(d.timeIntervalSince1970 * 1000), now: now)
    }

    /// `{"videos":[…]}` from the site's /videos/api/youtube; empty on anything odd.
    static func parseFeed(_ body: String) -> [VideoEntry] {
        guard let data = body.data(using: .utf8), let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let arr = o["videos"] as? [[String: Any]] else { return [] }
        return arr.compactMap { v in
            guard let id = v["videoId"] as? String, let title = v["title"] as? String else { return nil }
            return VideoEntry(videoId: id, title: title, published: v["published"] as? String, tags: v["tags"] as? [String], hero: v["hero"] as? Bool, channel: v["channel"] as? String)
        }
    }
}
