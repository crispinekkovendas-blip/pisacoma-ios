import XCTest

/// /descargas: the first open is the chooser and nothing else; the four modes; offline states.
final class DescargasUITests: XCTestCase {
    private let modes = ["todo", "esencial", "uso", "en-linea"]

    func testFirstRunShowsTheFourOptionsAndNothingElse() {
        let app = UI.launch(["-firstRun"], mode: nil)
        UI.waitFor(app, "descargas")
        for m in modes { UI.waitFor(app, "modo-\(m)") }
        XCTAssertFalse(UI.element(app, "nav-menu").exists, "the chooser must not show the menu button")
        let cont = UI.waitFor(app, "descargas-continuar")
        XCTAssertFalse(cont.isEnabled)
        UI.shot(app, "descargas-primera-vez", self)
    }

    func testChooseUsoContinuesToTheHome() {
        let app = UI.launch(["-firstRun"], mode: nil)
        UI.tap(app, "modo-uso")
        let cont = UI.waitFor(app, "descargas-continuar")
        XCTAssertTrue(cont.isEnabled)
        UI.shot(app, "descargas-uso-elegido", self)
        cont.tap()
        UI.waitFor(app, "home", timeout: 20)
        UI.shot(app, "home-tras-descargas", self)
    }

    func testOfflineFirstRunShowsTheErrorState() {
        let app = UI.launch(["-firstRun", "-wipeContent", "-forceOffline"], seeded: false, mode: nil)
        UI.tap(app, "modo-todo")
        let error = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'No se pudo guardar todo'")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 40))
        UI.shot(app, "descargas-error", self)
        XCTAssertTrue(UI.waitFor(app, "descargas-continuar").isEnabled)
    }

    func testOfflineMissingContentShowsTheNotice() {
        let app = UI.launch(["-wipeContent", "-forceOffline"], seeded: false, mode: "uso")
        UI.menu(app, "Biblia")
        UI.waitFor(app, "sin-conexion", timeout: 20)
        UI.shot(app, "sin-conexion-biblia", self)
        UI.tap(app, "sin-conexion-descargas")
        UI.waitFor(app, "descargas")
        UI.shot(app, "descargas-desde-aviso", self)
    }
}
