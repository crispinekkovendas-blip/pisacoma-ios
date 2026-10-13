import Foundation

/// One announcement (site utils/anuncios.ts Anuncio). Dates are "YYYY-MM-DD" or "DD/MM/YYYY".
struct Anuncio: Codable, Equatable {
    let title: String
    let date: String
    var time: String? = nil
    var detail: String? = nil
    var until: String? = nil
}

/// What the home band shows (site AnuncioView).
struct AnuncioView: Equatable, Identifiable {
    let title: String
    let time: String?
    let detail: String?
    let dateLabel: String
    let isToday: Bool
    var id: String { title + dateLabel }
}

/// Port of the site's utils/anuncios.ts: CSV from a published Google Sheet + local entries, the 21-day window.
enum Anuncios {
    private static let lookaheadDays: Int64 = 21
    private static let maxItems = 5
    private static let day: Int64 = 86_400_000

    private static let iso = try! NSRegularExpression(pattern: "^(\\d{4})-(\\d{1,2})-(\\d{1,2})$")
    private static let dmy = try! NSRegularExpression(pattern: "^(\\d{1,2})/(\\d{1,2})/(\\d{4})$")

    /// 00:00 UTC of a civil date, or nil.
    static func parseDay(_ s: String?) -> Int64? {
        let v = (s ?? "").trimmingCharacters(in: .whitespaces)
        let ns = v as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let m = iso.firstMatch(in: v, range: range) {
            return Zmanim.utcMidnight(Int(ns.substring(with: m.range(at: 1)))!, Int(ns.substring(with: m.range(at: 2)))! - 1, Int(ns.substring(with: m.range(at: 3)))!)
        }
        if let m = dmy.firstMatch(in: v, range: range) {
            return Zmanim.utcMidnight(Int(ns.substring(with: m.range(at: 3)))!, Int(ns.substring(with: m.range(at: 2)))! - 1, Int(ns.substring(with: m.range(at: 1)))!)
        }
        return nil
    }

    /// Minimal RFC 4180 parser (quoted fields, "" escapes, CRLF); blank rows dropped.
    static func parseCsv(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" && i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                else if c == "\"" { quoted = false }
                else { field.append(c) }
            } else if c == "\"" { quoted = true }
            else if c == "," { row.append(field); field = "" }
            else if c == "\n" || c == "\r" {
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""; rows.append(row); row = []
            } else { field.append(c) }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows.filter { r in r.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    private static let header = [
        "titulo": "title", "title": "title", "anuncio": "title",
        "fecha": "date", "date": "date", "dia": "date",
        "hora": "time", "time": "time",
        "detalle": "detail", "detalles": "detail", "descripcion": "detail", "detail": "detail",
        "hasta": "until", "until": "until", "fin": "until",
    ]
    private static func fold(_ s: String) -> String { s.folding(options: [.diacriticInsensitive], locale: nil).trimmingCharacters(in: .whitespaces).lowercased() }

    static func fromCsv(_ text: String) -> [Anuncio] {
        let rows = parseCsv(text)
        guard let head = rows.first else { return [] }
        let keys = head.map { header[fold($0)] }
        if !keys.contains("title") || !keys.contains("date") { return [] }
        return rows.dropFirst().compactMap { r in
            var m: [String: String] = [:]
            for (i, k) in keys.enumerated() {
                let v = i < r.count ? r[i].trimmingCharacters(in: .whitespaces) : ""
                if let k, !v.isEmpty { m[k] = v }
            }
            guard let title = m["title"], let date = m["date"], parseDay(date) != nil else { return nil }
            return Anuncio(title: title, date: date, time: m["time"], detail: m["detail"], until: m["until"])
        }
    }

    /// Current or within the next three weeks, soonest first, at most five (site selectAnuncios).
    static func select(_ items: [Anuncio], _ nowUtc: Int64) -> [AnuncioView] {
        let today = Zmanim.localCivilDate(nowUtc)
        let horizon = today + lookaheadDays * day
        return items
            .compactMap { a -> (Anuncio, Int64, Int64)? in
                guard let d = parseDay(a.date) else { return nil }
                return (a, d, parseDay(a.until) ?? d)
            }
            .filter { $0.2 >= today && $0.1 <= horizon }
            .sorted { $0.1 < $1.1 }
            .prefix(maxItems)
            .map { a, d, _ in AnuncioView(title: a.title, time: a.time, detail: a.detail, dateLabel: Zmanim.dayLabel(d), isToday: d == today) }
    }

    /// Local entries plus the sheet (if configured and reachable), selected for today.
    static func load(local: [Anuncio], csvUrl: String, nowUtc: Int64) async -> [AnuncioView] {
        var sheet: [Anuncio] = []
        if !csvUrl.trimmingCharacters(in: .whitespaces).isEmpty, let text = try? await Http.get(csvUrl) { sheet = fromCsv(text) }
        return select(local + sheet, nowUtc)
    }
}
