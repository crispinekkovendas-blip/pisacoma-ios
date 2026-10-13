import Foundation

// The repositories over an AssetSource, one per content kind (Android `data/*Repository.kt`).
// Each is an actor so its cache is read and filled from one place at a time.

/// The three hymnals. Spanish and old-Portuguese hymns store `verses[]` where verseNumber 0 is
/// the chorus; the NHA stores `stanzas[]` with explicit stanza/chorus blocks. Both become
/// LyricBlocks in the order the site prints them (first stanza, chorus, remaining stanzas).
actor HymnRepository {
    private let assets: AssetSource
    private var cache: [HymnVariant: [Hymn]] = [:]
    private var featuredMap: [String: [Int]]?

    init(_ assets: AssetSource) { self.assets = assets }

    func all(_ variant: HymnVariant) async throws -> [Hymn] {
        if let c = cache[variant] { return c }
        let loaded = try await load(variant)
        cache[variant] = loaded
        return loaded
    }

    func get(_ variant: HymnVariant, _ number: Int) async throws -> Hymn? {
        try await all(variant).first { $0.number == number }
    }

    /// The site's FEATURED_HYMNS picks for the hymnal index.
    func featured(_ variant: HymnVariant) async throws -> [Int] {
        if featuredMap == nil {
            featuredMap = try AppJson.decode([String: [Int]].self, try await assets.read("data/featured-hymns.json"))
        }
        return featuredMap?[variant.slug] ?? []
    }

    private func load(_ variant: HymnVariant) async throws -> [Hymn] {
        let data = try await assets.read("data/\(variant.file).json")
        let root = try JSONSerialization.jsonObject(with: data)
        let entries: [[String: Any]]
        if let o = root as? [String: Any], let h = o["hymns"] as? [[String: Any]] { entries = h } else { entries = root as? [[String: Any]] ?? [] }
        return entries.map { Self.parse(variant, $0) }
    }

    private static func int(_ v: Any?) -> Int {
        if let i = v as? Int { return i }
        if let s = v as? String, let i = Int(s) { return i }
        if let d = v as? Double { return Int(d) }
        return 0
    }

    private static func text(_ v: Any?) -> String? {
        guard let s = v as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    static func parse(_ variant: HymnVariant, _ o: [String: Any]) -> Hymn {
        let number = int(o["number"])
        var blocks: [LyricBlock] = []
        if let verses = o["verses"] as? [[String: Any]] {
            let parsed: [(Int, [String])] = verses.map { v in
                let n = int(v["verseNumber"])
                let contents = v["contents"] as? [String] ?? []
                let lines = contents.flatMap { $0.components(separatedBy: "\n") }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                return (n, lines)
            }
            let chorus = parsed.first { $0.0 == 0 }
            let stanzas = parsed.filter { $0.0 != 0 }
            let ordered: [(Int, [String])]
            if let chorus, !stanzas.isEmpty { ordered = [stanzas[0], chorus] + stanzas.dropFirst() } else { ordered = parsed }
            blocks = ordered.map { n, lines in LyricBlock(type: n == 0 ? "chorus" : "stanza", lines: lines, stanzaNumber: n == 0 ? nil : n) }
        } else if let stanzas = o["stanzas"] as? [[String: Any]] {
            var n = 0
            blocks = stanzas.map { s in
                let type = (s["type"] as? String) ?? "stanza"
                let lines = s["lines"] as? [String] ?? []
                if type == "chorus" { return LyricBlock(type: type, lines: lines, stanzaNumber: nil) }
                n += 1
                return LyricBlock(type: type, lines: lines, stanzaNumber: n)
            }
        } else {
            let lyrics = (o["lyrics"] as? String) ?? ""
            let parts = lyrics.components(separatedBy: "\n\n")
            var i = 0
            for block in parts {
                let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if lines.isEmpty { continue }
                i += 1
                blocks.append(LyricBlock(type: "stanza", lines: lines, stanzaNumber: i))
            }
        }
        return Hymn(
            variant: variant,
            number: number,
            title: (o["title"] as? String) ?? "",
            bibleReference: text(o["bibleReference"]),
            mp3Url: text(o["mp3Url"]),
            mp3UrlInstr: text(o["mp3UrlInstr"]),
            ytId: text(o["ytId"]),
            blocks: blocks
        )
    }
}

/// Reina-Valera 1960, one JSON per book (`{"b": 1, "c": [[verse, …], …]}`), like the site.
actor BibleRepository {
    private struct BookFile: Codable { let b: Int; let c: [[String]] }
    private let assets: AssetSource
    private var bookList: [BibleBook]?
    private var cache: [Int: BookFile] = [:]

    init(_ assets: AssetSource) { self.assets = assets }

    func books() async throws -> [BibleBook] {
        if let b = bookList { return b }
        let b = try AppJson.decode([BibleBook].self, try await assets.read("data/bible-books.json"))
        bookList = b
        return b
    }

    func book(_ num: Int) async throws -> BibleBook? { try await books().first { $0.num == num } }

    /// Verses 1..n of a chapter (empty when the chapter does not exist).
    func chapter(_ book: Int, _ chapter: Int) async throws -> [String] {
        let file: BookFile
        if let f = cache[book] { file = f } else {
            file = try AppJson.decode(BookFile.self, try await assets.read("data/biblia/\(book).json"))
            cache[book] = file
        }
        guard chapter >= 1, chapter <= file.c.count else { return [] }
        return file.c[chapter - 1]
    }

    /// (verse number, text) for `from..to`, clamped to the chapter.
    func verses(_ book: Int, _ chapter: Int, _ from: Int, _ to: Int) async throws -> [(Int, String)] {
        let all = try await self.chapter(book, chapter)
        let last = max(from, to)
        return all.enumerated().map { ($0.offset + 1, $0.element) }.filter { $0.0 >= from && $0.0 <= last }
    }

    /// Aymara Bible («Qullan Arunaca») on Bible.com, as the site links it.
    nonisolated func aymaraUrl(_ book: Int, _ chapter: Int) -> String {
        "https://www.bible.com/bible/293/\(Self.usfm[book - 1]).\(chapter).AYOP"
    }

    static let usfm = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH",
        "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON",
        "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL", "MAT", "MRK", "LUK", "JHN", "ACT", "ROM", "1CO", "2CO", "GAL",
        "EPH", "PHP", "COL", "1TH", "2TH", "1TI", "2TI", "TIT", "PHM", "HEB", "JAS", "1PE", "2PE", "1JN", "2JN", "3JN",
        "JUD", "REV",
    ]
}

/// The 25 Ellen G. White books: the site's catalogue (egw-index.json) and one JSON per book.
actor EgwRepository {
    private struct IndexFile: Codable { let aisles: [EgwAisle]; let books: [EgwBookMeta] }
    private let assets: AssetSource
    private var indexFile: IndexFile?
    private var cache: [String: EgwBook?] = [:]

    init(_ assets: AssetSource) { self.assets = assets }

    private func index() async throws -> IndexFile {
        if let i = indexFile { return i }
        let i = try AppJson.decode(IndexFile.self, try await assets.read("data/egw-index.json"))
        indexFile = i
        return i
    }

    func catalogue() async throws -> [EgwBookMeta] { try await index().books }
    func aisles() async throws -> [EgwAisle] { try await index().aisles }
    func meta(_ slug: String) async throws -> EgwBookMeta? { try await catalogue().first { $0.slug == slug } }

    /// The four «pasillos» in the site's order, each with its books.
    func rails() async throws -> [(EgwAisle, [EgwBookMeta])] {
        let i = try await index()
        return i.aisles.map { a in (a, i.books.filter { $0.aisle == a.roman }) }
    }

    func book(_ slug: String) async throws -> EgwBook? {
        if let c = cache[slug] { return c }
        let path = "data/egw/\(slug).json"
        var b: EgwBook? = nil
        if await assets.exists(path) { b = try AppJson.decode(EgwBook.self, try await assets.read(path)) }
        cache[slug] = b
        return b
    }
}

/// The current quarterly (escuela-sabatica.json).
actor QuarterlyRepository {
    private let assets: AssetSource
    private var cached: Quarterly?
    init(_ assets: AssetSource) { self.assets = assets }
    func quarterly() async throws -> Quarterly {
        if let q = cached { return q }
        let q = try AppJson.decode(Quarterly.self, try await assets.read("data/escuela-sabatica.json"))
        cached = q
        return q
    }
}

/// The quiz packs, newest first (the order of the site's QUIZZES array).
actor QuizRepository {
    private let assets: AssetSource
    private var cached: [QuizPack]?
    init(_ assets: AssetSource) { self.assets = assets }
    func packs() async throws -> [QuizPack] {
        if let p = cached { return p }
        let p = try AppJson.decode([QuizPack].self, try await assets.read("data/quizzes.json"))
        cached = p
        return p
    }
    func pack(_ slug: String) async throws -> QuizPack? { try await packs().first { $0.slug == slug } }
    func forLesson(_ n: Int) async throws -> QuizPack? { try await packs().first { $0.lessonNumber == n } }
}

/// The church facts (church.json).
actor ChurchRepository {
    private let assets: AssetSource
    private var cached: Church?
    init(_ assets: AssetSource) { self.assets = assets }
    func church() async throws -> Church {
        if let c = cached { return c }
        let c = try AppJson.decode(Church.self, try await assets.read("data/church.json"))
        cached = c
        return c
    }
}

/// The site's search-index.json (scripts/gen-search-index.mjs), parsed into typed rows.
actor SearchRepository {
    private let assets: AssetSource
    private var cached: SearchIndex?
    init(_ assets: AssetSource) { self.assets = assets }

    func index() async throws -> SearchIndex {
        if let i = cached { return i }
        let i = try Self.parse(try await assets.read("data/search-index.json"))
        cached = i
        return i
    }

    static func parse(_ data: Data) throws -> SearchIndex {
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AssetError.notFound("search-index") }
        func int(_ v: Any?) -> Int { (v as? Int) ?? Int((v as? String) ?? "") ?? Int((v as? Double) ?? 0) }
        let q = o["quarter"] as? [String: Any] ?? [:]
        let hymns = (o["hymns"] as? [[Any]] ?? []).map { a in
            SearchIndex.HymnRow(variant: a[0] as? String ?? "", number: int(a[1]), title: a[2] as? String ?? "", lines: a.count > 3 ? (a[3] as? [String] ?? []) : [])
        }
        let egw = (o["egw"] as? [[String: Any]] ?? []).map { r in
            SearchIndex.EgwRow(
                s: r["s"] as? String ?? "", t: r["t"] as? String ?? "",
                c: (r["c"] as? [[Any]] ?? []).map { SearchIndex.EgwChapterRef(number: int($0[0]), title: $0[1] as? String ?? "") }
            )
        }
        let lessons = (o["lessons"] as? [[String: Any]] ?? []).map { r in
            SearchIndex.LessonRow(n: int(r["n"]), t: r["t"] as? String ?? "", d: r["d"] as? [String] ?? [])
        }
        let bible = (o["bible"] as? [[Any]] ?? []).map { a in
            SearchIndex.BibleRow(num: int(a[0]), name: a[1] as? String ?? "", chapters: int(a[2]), abbr: a.count > 3 ? (a[3] as? String ?? "") : "")
        }
        return SearchIndex(v: int(o["v"]), quarter: .init(id: q["id"] as? String ?? "", title: q["title"] as? String ?? ""), hymns: hymns, egw: egw, lessons: lessons, bible: bible)
    }
}
