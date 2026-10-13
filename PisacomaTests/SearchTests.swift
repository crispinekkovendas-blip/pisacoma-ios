import XCTest
@testable import Pisacoma

/// Port of the site's utils/search.ts over the bundled index: same scores, same rows, same hrefs.
final class SearchTests: XCTestCase {
    private static var index: SearchIndex!

    override class func setUp() {
        super.setUp()
        let exp = XCTestExpectation(description: "index")
        Task {
            index = try await SearchRepository(ModelsParseTests.assets).index()
            exp.fulfill()
        }
        _ = XCTWaiter.wait(for: [exp], timeout: 30)
    }

    private var index: SearchIndex { Self.index }

    func testNormalizeFoldsAccentsAndPunctuation() {
        XCTAssertEqual(Search.normalize("¡Señor, dame paz!"), "senor dame paz")
        XCTAssertEqual(Search.normalize("«Santo, Santo, Santo»"), "santo santo santo")
    }

    func testScoreTitleRules() {
        let q = Search.normalize("santo")
        let tokens = q.split(separator: " ").map(String.init)
        XCTAssertEqual(Search.scoreTitle(q, tokens, "Santo"), 100)
        XCTAssertEqual(Search.scoreTitle(q, tokens, "Santo, santo, santo"), 60)
        XCTAssertEqual(Search.scoreTitle(q, tokens, "Cantad alegres"), 0)
        XCTAssertEqual(Search.scoreTitle(q, tokens, "Dios santo"), 12 + 6)
        XCTAssertEqual(Search.scoreTitle(q, tokens, "El Dios santo de los ejércitos de Israel"), 12 + 3)
    }

    func testExplicitReferenceScores200() {
        let g = Search.search(index, "juan 3:16")
        XCTAssertEqual(g.bible.count, 1)
        XCTAssertEqual(g.bible[0].title, "Juan 3:16")
        XCTAssertEqual(g.bible[0].score, 200)
        XCTAssertEqual(g.bible[0].href, "/biblia/?libro=43&cap=3&v=16")
        XCTAssertEqual(g.bible[0].num, "Jn")
    }

    func testPhoneStyleReferences() {
        XCTAssertEqual(Search.search(index, "salmo 23").bible.first?.title, "Salmos 23")
        XCTAssertEqual(Search.search(index, "1 cor 13 4").bible.first?.title, "1 Corintios 13:4")
        XCTAssertEqual(Search.search(index, "2co 10:4-5").bible.first?.title, "2 Corintios 10:4-5")
        XCTAssertEqual(Search.search(index, "corintios 13").bible.map(\.title), ["1 Corintios 13", "2 Corintios 13"])
    }

    func testBookNameAloneListsTheBook() {
        let g = Search.search(index, "génesis")
        XCTAssertEqual(g.bible.first?.title, "Génesis")
        XCTAssertEqual(g.bible.first?.caption, "Biblia · 50 capítulos")
        XCTAssertEqual(g.bible.first?.href, "/biblia/?libro=1&cap=1")
    }

    func testHymnNumberInEveryHymnal() {
        let g = Search.search(index, "307")
        XCTAssertEqual(g.hymns.count, 3)
        XCTAssertTrue(g.hymns.allSatisfy { $0.num == "307" })
        XCTAssertEqual(g.hymns.first?.href, "/himnario/es/307/")
        XCTAssertTrue(g.egw.isEmpty)
    }

    func testLessonNumberWord() {
        let g = Search.search(index, "lección 6")
        XCTAssertTrue(g.hymns.isEmpty)
        XCTAssertEqual(g.lessons.first?.num, "6")
        XCTAssertEqual(g.lessons.first?.href, "/escuela-sabatica/6/")
        XCTAssertEqual(g.lessons.first?.score, 110)
    }

    func testHymnTitleAndLyricLine() {
        let g = Search.search(index, "santo santo santo")
        XCTAssertFalse(g.hymns.isEmpty)
        XCTAssertEqual(g.hymns.first?.score, 100)
        XCTAssertEqual(g.hymns.first?.caption, "Hinário Antigo · Português")
        let es61 = g.hymns.first { $0.href == "/himnario/es/61/" }
        XCTAssertEqual(es61?.score, 61)
        XCTAssertEqual(es61?.caption, "Himnario Adventista · Español")
    }

    func testEgwBookTitleGetsTheBonus() {
        let g = Search.search(index, "camino a cristo")
        let book = g.egw.first
        XCTAssertEqual(book?.num, "§")
        XCTAssertEqual(book?.title, "El Camino a Cristo")
        XCTAssertEqual(book?.href, "/egw/cc/")
        XCTAssertTrue(g.egw.contains { $0.href == "/egw/cc/?ch=1" })
    }

    func testLessonDayTitles() {
        let g = Search.search(index, "pablo")
        XCTAssertTrue(g.lessons.contains { $0.num == "1.1" && $0.href == "/escuela-sabatica/1/?dia=1" })
    }

    func testEmptyQuery() {
        XCTAssertEqual(Search.search(index, "   ").total, 0)
    }
}
