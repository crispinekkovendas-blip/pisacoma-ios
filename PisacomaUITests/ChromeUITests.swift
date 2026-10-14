import XCTest

/// The top bar and the full menu around every screen.
final class ChromeUITests: XCTestCase {
    func testMenuOpensAndNavigates() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.shot(app, "chrome-home", self)
        UI.tap(app, "nav-menu")
        UI.waitFor(app, "menu-panel")
        UI.shot(app, "chrome-menu", self)
        UI.tap(app, "menu-Himnario")
        UI.waitFor(app, "hymn-list")
        UI.tap(app, "nav-search")
        UI.waitFor(app, "search-page")
        UI.shot(app, "buscar", self)
    }

    func testMenuHasTheElevenDestinationsAndDescargas() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.tap(app, "nav-menu")
        UI.waitFor(app, "menu-panel")
        for label in ["Inicio", "Visítanos", "Himnario", "Videos", "Esc. Sabática", "Biblia", "Diccionario", "EGW", "Quiz", "¿Quién?", "Buscar"] {
            XCTAssertTrue(UI.element(app, "menu-\(label)").exists, "menu-\(label) missing")
        }
        UI.tap(app, "menu-descargas")
        UI.waitFor(app, "descargas")
        UI.shot(app, "descargas-desde-menu", self)
    }
}
