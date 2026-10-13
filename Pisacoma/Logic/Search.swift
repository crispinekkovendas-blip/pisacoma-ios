import Foundation

enum ResultKind { case bible, hymn, egw, lesson }

/// One row of results (site utils/search.ts SearchHit); `href` is the site path, parsed by Route.parse.
struct SearchHit: Equatable, Identifiable {
    let kind: ResultKind
    /// Big italic numeral shown on the row (hymn number, chapter, lesson).
    let num: String
    let title: String
    /// Small caption under the title.
    let caption: String
    let href: String
    let score: Int
    var id: String { href + "|" + title }
}

struct SearchGroups: Equatable {
    let bible: [SearchHit]
    let hymns: [SearchHit]
    let egw: [SearchHit]
    let lessons: [SearchHit]
    var total: Int { bible.count + hymns.count + egw.count + lessons.count }
    static let empty = SearchGroups(bible: [], hymns: [], egw: [], lessons: [])
}

/// Line-by-line port of the site's utils/search.ts over the bundled index.
enum Search {
    private static let variantLabel = [
        "es": "Himnario Adventista · Español",
        "pt": "Hinário Antigo · Português",
        "pt-novo": "Novo Hinário · Português",
    ]

    private static let punct = try! NSRegularExpression(pattern: "[«»\"'“”‘’.,;:!¡?¿()\\[\\]]")
    private static let spaces = try! NSRegularExpression(pattern: "\\s+")

    private static func replace(_ re: NSRegularExpression, _ s: String, _ with: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: with)
    }

    private static func stripAccents(_ s: String) -> String { s.folding(options: [.diacriticInsensitive], locale: nil) }

    static func normalize(_ s: String) -> String {
        var t = stripAccents(s).lowercased()
        t = replace(punct, t, " ")
        t = replace(spaces, t, " ")
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// 0 = no match; higher is better. Every query token must appear.
    static func scoreTitle(_ qNorm: String, _ tokens: [String], _ title: String) -> Int {
        let t = normalize(title)
        if t.isEmpty { return 0 }
        if t == qNorm { return 100 }
        if t.hasPrefix(qNorm) { return 60 }
        let words = t.split(separator: " ").map(String.init)
        var score = 0
        for tok in tokens {
            if words.contains(tok) { score += 12 }
            else if words.contains(where: { $0.hasPrefix(tok) }) { score += 8 }
            else if t.contains(tok) { score += 4 }
            else { return 0 }
        }
        return score + max(0, 6 - t.count / 12)
    }

    // Abbreviations that are not a prefix of the book name (after accent folding).
    private static let bookAliases = [
        "gn": "genesis", "lv": "levitico", "nm": "numeros", "dt": "deuteronomio", "rt": "rut",
        "cnt": "cantares", "lm": "lamentaciones", "dn": "daniel", "jl": "joel", "mt": "mateo",
        "mr": "marcos", "mc": "marcos", "lc": "lucas", "jn": "juan", "hch": "hechos",
        "flp": "filipenses", "flm": "filemon", "ts": "tesalonicenses", "stg": "santiago",
        "sant": "santiago", "sl": "salmos", "cr": "cronicas", "co": "corintios", "s": "samuel",
        "r": "reyes", "p": "pedro", "ti": "timoteo",
    ]

    private static func refFold(_ s: String) -> String {
        replace(spaces, stripAccents(s).lowercased(), " ").trimmingCharacters(in: .whitespaces)
    }

    private static let phoneRef = try! NSRegularExpression(pattern: "^(?:([1-3])\\s*)?([a-zñ]+(?: [a-zñ]+)*?)\\.?\\s*(\\d{1,3})(?:\\s*[:., ]\\s*(\\d{1,3})(?:\\s*[-–]\\s*(\\d{1,3}))?)?$")
    private static let numPrefixRe = try! NSRegularExpression(pattern: "^(?:([1-3]) )?(.+)$")

    private static func groups(_ m: NSTextCheckingResult, _ s: String) -> [String?] {
        let ns = s as NSString
        return (0..<m.numberOfRanges).map { i in let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r) }
    }

    /// A whole-query reference typed the phone way: "juan 3:16", "salmo 23", "1 cor 13 4", "2co 10:4-5".
    static func parseReference(_ raw: String, _ books: [SearchIndex.BibleRow]) -> [SearchHit] {
        let folded = refFold(raw)
        guard let m = phoneRef.firstMatch(in: folded, range: NSRange(location: 0, length: (folded as NSString).length)) else { return [] }
        let g = groups(m, folded)
        let prefix = g[1]
        let stemRaw = g[2] ?? ""
        let stem = bookAliases[stemRaw] ?? stemRaw
        let ch = Int(g[3] ?? "") ?? 0
        let v1 = Int(g[4] ?? "") ?? 0
        let v2 = Int(g[5] ?? "") ?? 0

        struct P { let book: SearchIndex.BibleRow; let num: String; let base: String }
        let parsed: [P] = books.map { b in
            let f = refFold(b.name)
            let fm = numPrefixRe.firstMatch(in: f, range: NSRange(location: 0, length: (f as NSString).length))!
            let fg = groups(fm, f)
            return P(book: b, num: fg[1] ?? "", base: fg[2] ?? "")
        }
        let matches = { (base: String) -> Bool in base == stem || (stem.count >= 2 && base.hasPrefix(stem)) }
        var candidates = parsed.filter { $0.num == (prefix ?? "") && matches($0.base) }
        if candidates.isEmpty && prefix == nil { candidates = parsed.filter { !$0.num.isEmpty && matches($0.base) } }
        let exact = candidates.filter { $0.base == stem }
        let picked = (exact.isEmpty ? candidates : exact).prefix(3).map { $0.book }

        var hits: [SearchHit] = []
        for b in picked {
            if ch < 1 || ch > b.chapters { continue }
            let verses = v1 > 0 ? ":\(v1)" + (v2 > v1 ? "-\(v2)" : "") : ""
            hits.append(SearchHit(
                kind: .bible, num: b.abbr, title: "\(b.name) \(ch)\(verses)",
                caption: v1 > 0 ? "Biblia · Reina-Valera 1960 · abrir en el versículo" : "Biblia · Reina-Valera 1960 · abrir el capítulo",
                href: "/biblia/?libro=\(b.num)&cap=\(ch)" + (v1 > 0 ? "&v=\(v1)" : ""),
                score: 200
            ))
        }
        return hits
    }

    private static let numQuery = try! NSRegularExpression(pattern: "^(himno|hino|leccion|lec\\.?|#)?\\s*#?\\s*(\\d{1,3})$")

    static func search(_ index: SearchIndex?, _ query: String) -> SearchGroups {
        let raw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index, !raw.isEmpty else { return .empty }
        let qNorm = normalize(raw)
        let tokens = qNorm.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if tokens.isEmpty { return .empty }
        let folded = refFold(raw)
        let numMatch = numQuery.firstMatch(in: folded, range: NSRange(location: 0, length: (folded as NSString).length))
        var asNumber: Int? = nil
        var numWord = ""
        if let nm = numMatch {
            let g = groups(nm, folded)
            asNumber = Int(g[2] ?? "")
            numWord = g[1] ?? ""
        }
        let hymnNumbers = !numWord.hasPrefix("lec")
        let lessonNumbers = !numWord.hasPrefix("hi")

        // --- Bible
        var bible = parseReference(raw, index.bible)
        let bookByNum = Dictionary(index.bible.map { ($0.num, $0) }, uniquingKeysWith: { a, _ in a })
        if bible.isEmpty {
            for ref in BibleRefs.findRefs(raw) {
                guard let first = ref.sections.first, let book = bookByNum[ref.bookNum] else { continue }
                let v = first.from > 0 ? ":\(first.from)" + (first.to > 0 && first.to != first.from ? "-\(first.to)" : "") : ""
                bible.append(SearchHit(
                    kind: .bible, num: book.abbr, title: "\(book.name) \(first.chapter)\(v)",
                    caption: "Biblia · Reina-Valera 1960 · abrir el capítulo",
                    href: "/biblia/?libro=\(book.num)&cap=\(first.chapter)" + (first.from > 0 ? "&v=\(first.from)" : ""),
                    score: 200
                ))
                if bible.count >= 3 { break }
            }
        }
        if bible.isEmpty && asNumber == nil {
            for b in index.bible {
                var s = scoreTitle(qNorm, tokens, b.name)
                if s == 0 && normalize(b.abbr) == qNorm { s = 50 }
                if s == 0 { continue }
                bible.append(SearchHit(kind: .bible, num: b.abbr, title: b.name, caption: "Biblia · \(b.chapters) capítulos", href: "/biblia/?libro=\(b.num)&cap=1", score: s))
            }
            bible.sort { $0.score > $1.score }
            if bible.count > 4 { bible = Array(bible.prefix(4)) }
        }

        // --- Hymns
        var hymns: [SearchHit] = []
        for h in index.hymns {
            var s = 0
            var viaLine = ""
            if let n = asNumber {
                if hymnNumbers && h.number == n { s = 100 }
            } else {
                s = scoreTitle(qNorm, tokens, h.title)
                for line in h.lines {
                    let ls = scoreTitle(qNorm, tokens, line) - 2
                    if ls > s { s = ls; viaLine = line }
                }
            }
            if s <= 0 { continue }
            let label = variantLabel[h.variant] ?? h.variant
            hymns.append(SearchHit(
                kind: .hymn, num: String(h.number), title: h.title,
                caption: viaLine.isEmpty ? label : "«\(viaLine)…» · \(label)",
                href: "/himnario/\(h.variant)/\(h.number)/",
                score: s + (h.variant == "es" ? 1 : 0)
            ))
        }
        hymns.sort { $0.score != $1.score ? $0.score > $1.score : $0.title < $1.title }

        // --- EGW
        var egw: [SearchHit] = []
        if asNumber == nil {
            for book in index.egw {
                let bs = scoreTitle(qNorm, tokens, book.t)
                if bs != 0 { egw.append(SearchHit(kind: .egw, num: "§", title: book.t, caption: "Elena G. de White · \(book.c.count) capítulos", href: "/egw/\(book.s)/", score: bs + 20)) }
                for c in book.c {
                    let s = scoreTitle(qNorm, tokens, c.title)
                    if s == 0 { continue }
                    egw.append(SearchHit(kind: .egw, num: String(c.number), title: c.title, caption: "\(book.t) · Capítulo \(c.number)", href: "/egw/\(book.s)/?ch=\(c.number)", score: s))
                }
            }
            egw.sort { $0.score != $1.score ? $0.score > $1.score : $0.title < $1.title }
        }

        // --- Lessons
        var lessons: [SearchHit] = []
        for l in index.lessons {
            let ls: Int
            if let n = asNumber { ls = (lessonNumbers && l.n == n) ? 100 : 0 } else { ls = scoreTitle(qNorm, tokens, l.t) }
            if ls != 0 { lessons.append(SearchHit(kind: .lesson, num: String(l.n), title: l.t, caption: "Escuela Sabática · Lección \(l.n) · \(index.quarter.title)", href: "/escuela-sabatica/\(l.n)/", score: ls + 10)) }
            if asNumber != nil { continue }
            for (i, dayTitle) in l.d.enumerated() {
                if i == 0 || dayTitle.isEmpty { continue }
                let s = scoreTitle(qNorm, tokens, dayTitle)
                if s == 0 { continue }
                lessons.append(SearchHit(kind: .lesson, num: "\(l.n).\(i)", title: dayTitle, caption: "Lección \(l.n) · \(l.t) · Día \(i + 1)", href: "/escuela-sabatica/\(l.n)/?dia=\(i)", score: s))
            }
        }
        lessons.sort { $0.score > $1.score }

        return SearchGroups(bible: bible, hymns: hymns, egw: egw, lessons: lessons)
    }
}
