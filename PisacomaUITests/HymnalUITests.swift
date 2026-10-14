import XCTest

/// Himnario: index, a hymn page, the projector.
final class HymnalUITests: XCTestCase {
    func testIndexHymnPageAndProjector() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Himnario")
        UI.waitFor(app, "hymn-list")
        UI.waitFor(app, "hymn-count")
        UI.shot(app, "himnario-index", self)
        UI.tap(app, "pick-1")
        UI.waitFor(app, "hymn-page")
        UI.waitFor(app, "hymn-lyrics")
        UI.shot(app, "himno-es-1", self)
        UI.tap(app, "hymn-project")
        UI.waitFor(app, "projector")
        UI.shot(app, "himno-proyectar", self)
        UI.tap(app, "projector-next")
        UI.shot(app, "himno-proyectar-estrofa", self)
        UI.tap(app, "projector-close")
        UI.waitFor(app, "hymn-page")
    }

    func testRecentHymnAppearsAfterOpening() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Himnario")
        UI.tap(app, "pick-61")
        UI.waitFor(app, "hymn-page")
        UI.tap(app, "hymn-index")
        UI.waitFor(app, "hymn-list")
        UI.waitFor(app, "recent-61")
    }
}
