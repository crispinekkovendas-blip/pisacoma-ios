import XCTest
@testable import Pisacoma

final class ManifestTests: XCTestCase {
    private let m = try! Manifest.parse(Data("""
    {"generated":"2026-10-13","files":[
      {"path":"data/himnario-es.json","bytes":1000,"pack":"himnario-es"},
      {"path":"data/biblia/1.json","bytes":2000,"pack":"biblia"},
      {"path":"data/egw/cc.json","bytes":4000,"pack":"egw"}]}
    """.utf8))

    func testBytesOfPacks() { XCTAssertEqual(m.bytesOf(["himnario-es", "biblia"]), 3000) }
    func testTotalBytes() { XCTAssertEqual(m.totalBytes, 7000) }
    func testFilesForTodoIsEverything() { XCTAssertEqual(m.filesFor(.todo).count, 3) }
    func testFilesForEsencialSkipsEgw() { XCTAssertEqual(m.filesFor(.esencial).map(\.path), ["data/himnario-es.json", "data/biblia/1.json"]) }
    func testFilesForUsoAndOnlineAreEmpty() {
        XCTAssertEqual(m.filesFor(.uso).count, 0)
        XCTAssertEqual(m.filesFor(.enLinea).count, 0)
    }
    func testByPath() {
        XCTAssertEqual(m.byPath("data/biblia/1.json")?.bytes, 2000)
        XCTAssertNil(m.byPath("nope"))
    }
    func testModeOf() {
        XCTAssertEqual(ContentMode.of("en-linea"), .enLinea)
        XCTAssertNil(ContentMode.of(nil))
        XCTAssertNil(ContentMode.of("x"))
    }
    func testModeFlags() {
        XCTAssertTrue(ContentMode.esencial.downloads)
        XCTAssertFalse(ContentMode.uso.downloads)
        XCTAssertFalse(ContentMode.enLinea.persists)
        XCTAssertTrue(ContentMode.uso.persists)
    }
    func testFormatSizes() {
        XCTAssertEqual(formatMb(5_900_000), "5,9 MB")
        XCTAssertEqual(formatMb(29_400_000), "29 MB")
        XCTAssertEqual(formatMb(0), "0 MB")
        XCTAssertEqual(formatMb(331_000), "0,3 MB")
    }
    func testPackLabels() {
        XCTAssertEqual(Packs.label("egw"), "25 libros de Ellen G. White")
        XCTAssertEqual(Packs.essential, ["himnario-es", "biblia", "escuela", "buscar"])
    }
    func testBundledManifestLists97Files() throws {
        let url = Bundle.main.resourceURL!.appendingPathComponent("Content/manifest.json")
        let m = try Manifest.parse(try Data(contentsOf: url))
        XCTAssertEqual(m.files.count, 97)
        XCTAssertEqual(Set(m.files.map(\.pack)), Set(Packs.order))
    }
}
