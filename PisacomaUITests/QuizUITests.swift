import XCTest

/// Quiz: the index, picking an answer, the confirm modal, the locked answer.
final class QuizUITests: XCTestCase {
    func testPickConfirmLock() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Quiz")
        UI.waitFor(app, "quiz-index")
        UI.shot(app, "quiz-index", self)
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'quiz-card-'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        UI.waitFor(app, "quiz-page")
        UI.waitFor(app, "quiz-progress")
        UI.shot(app, "quiz-l13", self)
        UI.tap(app, "q1-B")
        UI.waitFor(app, "quiz-confirm")
        UI.shot(app, "quiz-confirm", self)
        UI.tap(app, "confirm-yes")
        UI.waitFor(app, "q1-locked")
        UI.shot(app, "quiz-locked", self)
    }
}
