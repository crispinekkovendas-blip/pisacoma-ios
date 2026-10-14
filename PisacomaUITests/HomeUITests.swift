import XCTest

/// Inicio «Un día en el Altiplano»: the scenes, an action, the pause button.
final class HomeUITests: XCTestCase {
    func testScenesActionAndPause() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.waitFor(app, "scene-inicio")
        UI.shot(app, "home-inicio", self)
        UI.tap(app, "scene-himnario-action")
        UI.waitFor(app, "hymn-list")
        UI.tap(app, "nav-brand")
        UI.waitFor(app, "home")
        UI.tap(app, "home-pause")
        UI.waitFor(app, "home-pause-on")
        UI.shot(app, "home-paused", self)
    }

    func testSabbathSceneShowsTheTimes() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        let times = UI.element(app, "sabado-times")
        for _ in 0..<12 where !times.exists { app.swipeUp() }
        XCTAssertTrue(times.waitForExistence(timeout: 10))
        UI.shot(app, "home-sabado", self)
    }
}
