import XCTest
@testable import Pisacoma

/// Site hrefs (as the bundled search index and the pages write them) map to routes one to one.
final class RouteTests: XCTestCase {
    func testPlainPaths() {
        XCTAssertEqual(Route.parse("/"), .home)
        XCTAssertEqual(Route.parse("/himnario/"), .himnario)
        XCTAssertEqual(Route.parse("/himnario/es/307/"), .hymn(variant: "es", number: 307))
        XCTAssertEqual(Route.parse("/videos/abc_12"), .video(id: "abc_12"))
        XCTAssertEqual(Route.parse("/quiz/leccion-13-gracia-amor-comunion"), .quizPack(slug: "leccion-13-gracia-amor-comunion"))
    }

    func testQueryStrings() {
        XCTAssertEqual(Route.parse("/biblia/?libro=43&cap=3&v=16"), .biblia(book: 43, chapter: 3, verse: 16))
        XCTAssertEqual(Route.parse("/biblia/?libro=1&cap=1"), .biblia(book: 1, chapter: 1, verse: nil))
        XCTAssertEqual(Route.parse("/biblia"), .biblia(book: nil, chapter: nil, verse: nil))
        XCTAssertEqual(Route.parse("/egw/cc/?ch=2"), .egwBook(slug: "cc", chapter: 2))
        XCTAssertEqual(Route.parse("/escuela-sabatica/4/?dia=2"), .leccion(number: 4, day: 2))
        XCTAssertEqual(Route.parse("/escuela-sabatica/4/"), .leccion(number: 4, day: nil))
    }

    func testUniversalLinkKeepsTheQuery() {
        XCTAssertEqual(Route.parse(url: URL(string: "https://quiz-qwik.vercel.app/biblia/?libro=43&cap=3&v=16")!), .biblia(book: 43, chapter: 3, verse: 16))
        XCTAssertEqual(Route.parse(url: URL(string: "https://quiz-qwik.vercel.app/")!), .home)
    }

    func testPathsRoundTrip() {
        XCTAssertEqual(Route.biblia(book: 43, chapter: 3, verse: 16).path, "/biblia?libro=43&cap=3&v=16")
        XCTAssertEqual(Route.leccion(number: 4, day: 2).path, "/escuela-sabatica/4?dia=2")
        XCTAssertEqual(Route.egwBook(slug: "cc", chapter: nil).path, "/egw/cc")
        XCTAssertEqual(Route.biblia(book: 43, chapter: 3, verse: 16).base, "/biblia")
    }

    func testDescargasIsAnAppOnlyPastelRoute() {
        XCTAssertEqual(Route.parse("/descargas"), .descargas)
        XCTAssertEqual(Route.descargas.path, "/descargas")
        XCTAssertEqual(Route.descargas.skin, .pastel)
    }

    func testSkins() {
        XCTAssertEqual(Route.home.skin, .home)
        XCTAssertEqual(Route.quiz.skin, .dark)
        XCTAssertEqual(Route.video(id: "x").skin, .dark)
        XCTAssertEqual(Route.himnario.skin, .pastel)
    }

    func testUnknownIsNil() { XCTAssertNil(Route.parse("/nada")) }

    func testNavItemsAreTheSitesEleven() {
        XCTAssertEqual(navItems.count, 11)
        XCTAssertEqual(navItems.map(\.label), ["Inicio", "Visítanos", "Himnario", "Videos", "Esc. Sabática", "Biblia", "Diccionario", "EGW", "Quiz", "¿Quién?", "Buscar"])
    }

    func testQuarterLabel() {
        // 2026-10-13T15:00Z → Q4 in Lima
        XCTAssertEqual(quarterLabel(1_791_903_600_000), "Trimestre 2026·Q4")
    }

    @MainActor func testRouterFirstRunContinuesToTheDeepLink() {
        let r = Router(root: .descargas, after: .himnario)
        r.continueFirstRun()
        XCTAssertEqual(r.root, .home)
        XCTAssertEqual(r.path, [.himnario])
        let plain = Router(root: .descargas, after: nil)
        plain.continueFirstRun()
        XCTAssertEqual(plain.path, [])
    }

    @MainActor func testRouterGoIsSingleTop() {
        let r = Router()
        r.go(.himnario); r.go(.himnario)
        XCTAssertEqual(r.path, [.himnario])
        r.go(.home)
        XCTAssertEqual(r.path, [])
    }
}
