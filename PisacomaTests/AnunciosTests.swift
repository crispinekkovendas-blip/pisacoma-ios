import XCTest
@testable import Pisacoma

/// Port of the site's utils/anuncios.ts: CSV → Anuncio, and the 21-day window selection.
final class AnunciosTests: XCTestCase {
    private let csv = [
        "titulo,fecha,hora,detalle,hasta",
        "Culto de jóvenes,2026-09-20,3:00 PM,\"En el templo, con \"\"invitados\"\"\",",
        "Campaña,15/10/2026,,Toda la semana,22/10/2026",
        "Sin fecha,,,,",
        "Vigilia,2026-10-30,8:00 PM,,",
    ].joined(separator: "\n")

    private let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
    private func ms(_ s: String) -> Int64 { Int64(iso.date(from: s)!.timeIntervalSince1970 * 1000) }

    func testParseCsvHandlesQuotesAndCrlf() {
        XCTAssertEqual(Anuncios.parseCsv("a,b\r\n\"x, y\",\"q\"\"q\"\n"), [["a", "b"], ["x, y", "q\"q"]])
    }

    func testParseDayAcceptsBothFormats() {
        XCTAssertEqual(Anuncios.parseDay("2026-09-20"), ms("2026-09-20T00:00:00Z"))
        XCTAssertEqual(Anuncios.parseDay("15/10/2026"), ms("2026-10-15T00:00:00Z"))
        XCTAssertNil(Anuncios.parseDay(""))
        XCTAssertNil(Anuncios.parseDay("ayer"))
    }

    func testCsvToAnunciosWithHeaderAliases() {
        let items = Anuncios.fromCsv(csv)
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], Anuncio(title: "Culto de jóvenes", date: "2026-09-20", time: "3:00 PM", detail: "En el templo, con \"invitados\"", until: nil))
        XCTAssertEqual(items[1].until, "22/10/2026")
        XCTAssertTrue(Anuncios.fromCsv("nombre,cosa\na,b").isEmpty)
        XCTAssertTrue(Anuncios.fromCsv("").isEmpty)
    }

    func testSelectKeepsCurrentAndUpcomingWithinThreeWeeks() {
        let views = Anuncios.select(Anuncios.fromCsv(csv), ms("2026-10-13T15:00:00Z"))
        XCTAssertEqual(views.map(\.title), ["Campaña", "Vigilia"])
        XCTAssertEqual(views[0].dateLabel, "Jueves 15 oct")
        XCTAssertFalse(views[0].isToday)
    }

    func testSelectMarksTodayAndCapsAtFive() {
        let items = (1...7).map { Anuncio(title: "A\($0)", date: "2026-10-13") }
        let views = Anuncios.select(items, ms("2026-10-13T15:00:00Z"))
        XCTAssertEqual(views.count, 5)
        XCTAssertTrue(views.allSatisfy(\.isToday))
        XCTAssertEqual(views[0].dateLabel, "Martes 13 oct")
    }

    func testSelectIgnoresBeyondHorizon() {
        XCTAssertTrue(Anuncios.select([Anuncio(title: "Lejos", date: "2026-12-01")], ms("2026-10-13T15:00:00Z")).isEmpty)
    }
}
