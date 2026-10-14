import XCTest

/// EGW: the catalogue rails, a book, marking a chapter, the chapter list.
final class EgwUITests: XCTestCase {
    func testCatalogueAndBook() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "EGW")
        UI.waitFor(app, "egw-page")
        UI.waitFor(app, "rail-I")
        UI.shot(app, "egw-catalogo", self)
        UI.tap(app, "cover-cc")
        UI.waitFor(app, "egw-reader")
        UI.waitFor(app, "egw-chapter-title")
        UI.shot(app, "egw-libro-cc", self)
        UI.tap(app, "chapter-done-top")
        UI.tap(app, "egw-chapters")
        UI.waitFor(app, "egw-toc")
        UI.shot(app, "egw-capitulos", self)
        UI.tap(app, "chapter-2")
        UI.waitFor(app, "egw-reader")
        UI.tap(app, "egw-back")
        UI.waitFor(app, "egw-page")
        UI.waitFor(app, "continue-cc")
        UI.shot(app, "egw-catalogo-progreso", self)
    }
}
