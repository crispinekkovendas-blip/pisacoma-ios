import XCTest
@testable import Pisacoma

/// The models parse the real files: the app bundle's Content/ layered over the test bundle's TestContent/.
final class ModelsParseTests: XCTestCase {
    static let assets: AssetSource = CompositeAssetSource([
        FileAssetSource.bundled(.main),
        FileAssetSource(root: Bundle(for: ModelsParseTests.self).resourceURL!.appendingPathComponent("TestContent")),
    ])
    var assets: AssetSource { Self.assets }

    func testSpanishHymnalHas613Hymns() async throws {
        let hymns = try await HymnRepository(assets).all(.es)
        XCTAssertEqual(hymns.count, 613)
        let first = hymns[0]
        XCTAssertEqual(first.number, 1)
        XCTAssertEqual(first.title, "Cantad Alegres al señor")
        XCTAssertEqual(first.bibleReference, "Salmos 100:1-5")
        XCTAssertTrue(first.mp3Url!.hasPrefix("https://docs.google.com/"))
        XCTAssertNotNil(first.mp3UrlInstr)
        XCTAssertTrue(first.blocks[0].lines[0].hasPrefix("Cantad alegres al Señor"))
    }

    func testOldPortugueseHymnalHas610() async throws {
        let hymns = try await HymnRepository(assets).all(.pt)
        XCTAssertEqual(hymns.count, 610)
        XCTAssertTrue(hymns[0].mp3Url!.contains("Hina7"))
    }

    func testNovoHinarioHas601WithYouTubeIds() async throws {
        let hymns = try await HymnRepository(assets).all(.ptNovo)
        XCTAssertEqual(hymns.count, 601)
        XCTAssertEqual(hymns[0].ytId, "FDpludwY46U")
        XCTAssertEqual(hymns[0].blocks[0].type, "stanza")
    }

    func testHymnByNumberAndChorusOrder() async throws {
        let repo = HymnRepository(assets)
        let v1 = try await repo.get(.es, 1)?.title
        XCTAssertEqual(v1, "Cantad Alegres al señor")
        let v2 = try await repo.get(.es, 9999)
        XCTAssertNil(v2)
        // A hymn with a chorus prints stanza 1, the chorus, then the rest.
        let withChorus = try await repo.all(.es).first { h in h.blocks.contains { $0.isChorus } && h.blocks.count > 2 }!
        XCTAssertEqual(withChorus.blocks[0].stanzaNumber, 1)
        XCTAssertTrue(withChorus.blocks[1].isChorus)
    }

    func testFeaturedHymns() async throws {
        let v3 = try await HymnRepository(assets).featured(.es)
        XCTAssertEqual(v3, [1, 61, 115, 164, 303, 307, 400, 516])
    }

    func testBibleBooksAndGenesis() async throws {
        let repo = BibleRepository(assets)
        let books = try await repo.books()
        XCTAssertEqual(books.count, 66)
        XCTAssertEqual(books[0].name, "Génesis")
        XCTAssertEqual(books[0].chapters, 50)
        let ch1 = try await repo.chapter(1, 1)
        XCTAssertEqual(ch1.count, 31)
        XCTAssertTrue(ch1[0].hasPrefix("En el principio"))
        let range = try await repo.verses(43, 3, 16, 17)
        XCTAssertEqual(range.count, 2)
        XCTAssertEqual(range[0].0, 16)
        XCTAssertTrue(range[0].1.hasPrefix("Porque de tal manera"))
        XCTAssertEqual(repo.aymaraUrl(43, 3), "https://www.bible.com/bible/293/JHN.3.AYOP")
    }

    func testEgwCatalogueAndBook() async throws {
        let repo = EgwRepository(assets)
        let v4 = try await repo.catalogue().count
        XCTAssertEqual(v4, 25)
        let v5 = try await repo.rails().count
        XCTAssertEqual(v5, 4)
        let v6 = try await repo.catalogue()[0].slug
        XCTAssertEqual(v6, "cc")
        let cc = try await repo.book("cc")!
        XCTAssertEqual(cc.chapters[0].title, "El camino a Cristo")
        XCTAssertEqual(cc.chapters[1].title, "Capítulo 1— Amor supremo")
        XCTAssertTrue(cc.chapters.count > 10)
        let v7 = try await repo.book("nope")
        XCTAssertNil(v7)
    }

    func testQuarterlyHas13LessonsOf7Days() async throws {
        let q = try await QuarterlyRepository(assets).quarterly()
        XCTAssertEqual(q.lessons.count, 13)
        XCTAssertTrue(q.lessons.allSatisfy { $0.days.count == 7 })
        XCTAssertEqual(q.id, "2026-03")
        XCTAssertEqual(q.lessons[0].number, 1)
    }

    func testQuizzesParse() async throws {
        let repo = QuizRepository(assets)
        let packs = try await repo.packs()
        XCTAssertTrue(packs.count >= 5)
        XCTAssertTrue(packs.allSatisfy { $0.questions.count >= 5 })
        XCTAssertEqual(packs[0].lessonNumber, 13)
        let v8 = try await repo.pack(packs[0].slug)
        XCTAssertNotNil(v8)
    }

    func testChurchFacts() async throws {
        let c = try await ChurchRepository(assets).church()
        XCTAssertEqual(c.schedule.count, 3)
        XCTAssertEqual(c.schedule[0].name, "Escuela Sabática")
        XCTAssertEqual(c.location.lat, -16.908, accuracy: 1e-6)
        XCTAssertEqual(c.hierarchy.count, 5)
        XCTAssertEqual(c.pioneers.count, 3)
    }

    func testSearchIndexParses() async throws {
        let idx = try await SearchRepository(assets).index()
        XCTAssertTrue(idx.v >= 1)
        XCTAssertTrue(idx.hymns.count > 1800)
        XCTAssertEqual(idx.bible.count, 66)
        XCTAssertEqual(idx.lessons.count, 13)
    }
}
