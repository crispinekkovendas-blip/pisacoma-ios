import XCTest
@testable import Pisacoma

/// Port of the site's bibleStore.ts findRefs: same regex, same book map, same ParsedRef shape.
final class BibleRefsTests: XCTestCase {
    func testSimpleReference() {
        let refs = BibleRefs.findRefs("Lee Juan 3:16 hoy")
        XCTAssertEqual(refs.count, 1)
        let r = refs[0]
        XCTAssertEqual(r.bookNum, 43)
        XCTAssertEqual(r.bookName, "Juan")
        XCTAssertEqual(r.sections, [RefSection(chapter: 3, from: 16, to: 16)])
        XCTAssertEqual(r.display, "Juan 3:16")
        XCTAssertEqual(r.start, 4)
        XCTAssertEqual(r.end, 13)
    }

    func testAbbreviationWithDotAndRangeWithAl() {
        let r = BibleRefs.findRefs("1 Cor. 10:12 al 15")[0]
        XCTAssertEqual(r.bookNum, 46)
        XCTAssertEqual(r.bookName, "1 Corintios")
        XCTAssertEqual(r.sections, [RefSection(chapter: 10, from: 12, to: 15)])
    }

    func testSemicolonContinuationAddsSections() {
        let refs = BibleRefs.findRefs("Juan 3:16; 5:4-8 dice")
        XCTAssertEqual(refs.count, 1)
        XCTAssertEqual(refs[0].sections, [RefSection(chapter: 3, from: 16, to: 16), RefSection(chapter: 5, from: 4, to: 8)])
        XCTAssertEqual(refs[0].display, "Juan 3:16; 5:4-8")
    }

    func testAccentedAbbreviation() {
        XCTAssertEqual(BibleRefs.findRefs("Gén. 1:1")[0].bookNum, 1)
        XCTAssertEqual(BibleRefs.findRefs("Gálatas 1:1")[0].bookNum, 48)
    }

    func testSpaceAfterColonAsTheQuarterlyWrites() {
        let r = BibleRefs.findRefs("Hechos 17: 16-34")[0]
        XCTAssertEqual(r.bookNum, 44)
        XCTAssertEqual(r.sections, [RefSection(chapter: 17, from: 16, to: 34)])
    }

    func testPsalmsRange() {
        let r = BibleRefs.findRefs("Salmos 100:1-5")[0]
        XCTAssertEqual(r.bookNum, 19)
        XCTAssertEqual(r.sections, [RefSection(chapter: 100, from: 1, to: 5)])
    }

    func testSeveralReferencesInOneLine() {
        let refs = BibleRefs.findRefs("1 Corintios 1: 1; Gálatas 1: 1; Hechos 17: 16-34; 1 Corintios 5: 9-11; 2 Corintios 2: 4.")
        XCTAssertEqual(refs.map(\.bookNum), [46, 48, 44, 46, 47])
    }

    func testUnknownBookIsIgnored() {
        XCTAssertTrue(BibleRefs.findRefs("Capítulo 3:16 de un libro").isEmpty)
    }

    func testBookNamesTable() {
        XCTAssertEqual(BibleRefs.bookName(66), "Apocalipsis")
        XCTAssertEqual(BibleRefs.resolveBook("1 jn"), 62)
        XCTAssertNil(BibleRefs.resolveBook("nada"))
    }
}
