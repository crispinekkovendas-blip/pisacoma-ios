import XCTest

/// Escuela Sabática: the quarter overview, a lesson day, marking it done, the drawer.
final class LessonUITests: XCTestCase {
    func testOverviewLessonAndDone() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Esc. Sabática")
        UI.waitFor(app, "lesson-list")
        UI.waitFor(app, "current-lesson")
        UI.shot(app, "escuela-overview", self)
        UI.tap(app, "current-lesson")
        UI.waitFor(app, "lesson-page")
        UI.waitFor(app, "lesson-content")
        UI.shot(app, "escuela-lesson", self)
        UI.tap(app, "day-done")
        UI.waitFor(app, "lesson-notes")
        UI.tap(app, "lesson-notes")
        UI.waitFor(app, "lesson-drawer")
        UI.tap(app, "drawer-tab-progress")
        UI.shot(app, "escuela-drawer-progreso", self)
    }

    func testDayTabsSwitchTheDay() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Esc. Sabática")
        UI.tap(app, "lesson-1")
        UI.waitFor(app, "lesson-page")
        UI.tap(app, "day-tab-2")
        UI.waitFor(app, "day-tab-2-selected")
        UI.shot(app, "escuela-lesson-day3", self)
    }
}
