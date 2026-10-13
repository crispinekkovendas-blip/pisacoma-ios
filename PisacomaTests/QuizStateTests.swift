import XCTest
@testable import Pisacoma

/// The site's quiz-view.tsx state machine: pick → pending (modal) → confirm locks the answer;
/// nothing can be changed afterwards; «Ver resultados» submits; persisted as
/// `{"committed":{"1":"B"},"submitted":false}` under `quiz.<slug>.v1`.
final class QuizStateTests: XCTestCase {
    private let pack = QuizPack(
        slug: "t", lessonNumber: 1, title: "T", badge: "B", subtitle: "S",
        memorize: Memorize(text: "x", ref: "Jn 1:1"), metaTitle: "", metaDescription: "",
        questions: (1...3).map { n in
            QuizQuestion(n: n, text: "Q\(n)", ref: nil, options: [QuizOption(letter: "A", text: "a"), QuizOption(letter: "B", text: "b"), QuizOption(letter: "C", text: "c"), QuizOption(letter: "D", text: "d")], correct: "B", explain: "porque sí")
        },
        levels: nil
    )

    func testPickOpensTheConfirmModal() {
        let s = QuizState().requestCommit(1, "B")
        XCTAssertEqual(s.pending, QuizState.Pending(qN: 1, letter: "B"))
        XCTAssertTrue(s.committed.isEmpty)
    }

    func testCancelClosesWithoutCommitting() {
        let s = QuizState().requestCommit(1, "B").cancel()
        XCTAssertNil(s.pending)
        XCTAssertTrue(s.committed.isEmpty)
    }

    func testConfirmLocksTheAnswer() {
        let s = QuizState().requestCommit(1, "B").confirm()
        XCTAssertNil(s.pending)
        XCTAssertEqual(s.committed[1], "B")
        XCTAssertNil(s.requestCommit(1, "C").pending)
        XCTAssertEqual(s.requestCommit(1, "C").committed[1], "B")
    }

    func testScoreCountsCorrectCommittedAnswers() {
        let s = QuizState().requestCommit(1, "B").confirm().requestCommit(2, "A").confirm()
        XCTAssertEqual(s.score(pack), 1)
        XCTAssertEqual(s.committedCount, 2)
        XCTAssertFalse(s.allCommitted(pack))
        XCTAssertEqual(s.pct(pack), 67)
    }

    func testSubmitRevealsResultsAndBlocksPicks() {
        let s = QuizState().requestCommit(1, "B").confirm().submit()
        XCTAssertTrue(s.submitted)
        XCTAssertNil(s.requestCommit(2, "A").pending)
    }

    func testResetClearsEverything() {
        let s = QuizState().requestCommit(1, "B").confirm().submit().reset()
        XCTAssertTrue(s.committed.isEmpty)
        XCTAssertFalse(s.submitted)
        XCTAssertNil(s.pending)
    }

    func testLevelIsTheHighestMinScoreReached() {
        let levels = QuizState.defaultLevels
        XCTAssertEqual(QuizState.tier(15, levels).name, "Caleb")
        XCTAssertEqual(QuizState.tier(14, levels).name, "Caleb")
        XCTAssertEqual(QuizState.tier(11, levels).name, "Daniel")
        XCTAssertEqual(QuizState.tier(8, levels).name, "Débora")
        XCTAssertEqual(QuizState.tier(0, levels).name, "Josías")
        let custom = [QuizLevel(minScore: 2, name: "Alto", desc: "a"), QuizLevel(minScore: 0, name: "Bajo", desc: "b")]
        XCTAssertEqual(QuizState.tier(3, custom).name, "Alto")
    }

    func testDefaultLevelsMatchTheSite() {
        XCTAssertEqual(QuizState.defaultLevels.map(\.minScore), [14, 11, 8, 0])
        XCTAssertEqual(QuizState.defaultLevels[0].desc, "¡Excelente! Conoces bien la lección de esta semana.")
    }

    func testPersistedJsonMatchesTheSite() {
        let s = QuizState().requestCommit(1, "B").confirm().requestCommit(3, "D").confirm()
        XCTAssertEqual(s.toJson(), "{\"committed\":{\"1\":\"B\",\"3\":\"D\"},\"submitted\":false}")
        let back = QuizState.fromJson("{\"committed\":{\"1\":\"B\",\"3\":\"D\"},\"submitted\":true}")
        XCTAssertEqual(back.committed, [1: "B", 3: "D"])
        XCTAssertTrue(back.submitted)
        XCTAssertNil(back.pending)
        XCTAssertEqual(QuizState.fromJson("garbage"), QuizState())
        XCTAssertEqual(QuizState.fromJson(nil), QuizState())
    }
}
