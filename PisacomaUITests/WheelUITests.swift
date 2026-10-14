import XCTest

/// ¿Quién?: the wheel with the default names, add/remove, the pointer mode.
final class WheelUITests: XCTestCase {
    func testWheelAndPointer() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "¿Quién?")
        UI.waitFor(app, "quien-page")
        UI.waitFor(app, "wheel-segments-8")
        UI.shot(app, "quien-ruleta", self)
        UI.tap(app, "wheel-remove-Hermano 1")
        UI.waitFor(app, "wheel-segments-7")
        UI.tap(app, "mode-pointer")
        UI.waitFor(app, "pointer-spin")
        UI.shot(app, "quien-apuntador", self)
    }

    func testClearShowsTheEmptyWheel() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "¿Quién?")
        UI.tap(app, "wheel-clear")
        UI.waitFor(app, "wheel-empty")
        UI.shot(app, "quien-vacia", self)
    }
}
