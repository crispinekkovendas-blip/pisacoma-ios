import XCTest
@testable import Pisacoma

/// UserState over an in-memory store, keyed exactly like the site's localStorage.
final class UserStateTests: XCTestCase {
    private let state = UserState(MemoryStore())

    func testStringRoundTrip() {
        XCTAssertNil(state.string("biblia:bk1:ch1:notes"))
        state.set("biblia:bk1:ch1:notes", "hola")
        XCTAssertEqual(state.string("biblia:bk1:ch1:notes"), "hola")
        state.set("biblia:bk1:ch1:notes", nil)
        XCTAssertNil(state.string("biblia:bk1:ch1:notes"))
    }

    func testBoolDefaultsFalse() {
        XCTAssertFalse(state.bool("inicio.videos.pausa"))
        state.set("inicio.videos.pausa", true)
        XCTAssertTrue(state.bool("inicio.videos.pausa"))
        XCTAssertEqual(state.string("inicio.videos.pausa"), "1")
    }

    func testListIsStoredAsJsonArrayLikeTheSite() {
        state.set("biblia:bookmarks", ["1:1", "43:3"])
        XCTAssertEqual(state.string("biblia:bookmarks"), "[\"1:1\",\"43:3\"]")
        XCTAssertEqual(state.stringList("biblia:bookmarks"), ["1:1", "43:3"])
        XCTAssertEqual(state.stringList("missing"), [])
    }

    func testChangeListener() {
        var seen: [String] = []
        let token = state.onChange { seen.append($0) }
        state.set("egw:cc:last", "3")
        XCTAssertEqual(seen, ["egw:cc:last"])
        _ = token
    }

    func testKeysMatchTheSite() {
        XCTAssertEqual(UserState.Keys.bibleNotes(43, 3), "biblia:bk43:ch3:notes")
        XCTAssertEqual(UserState.Keys.egwDone("cc", 2), "egw:cc:ch2:done")
        XCTAssertEqual(UserState.Keys.egwNotes("cc", 2), "egw:cc:ch2:notes")
        XCTAssertEqual(UserState.Keys.egwLast("cc"), "egw:cc:last")
        XCTAssertEqual(UserState.Keys.lessonDone("2026-03", 4, 2), "escuela:2026-03:lecc4:day2:done")
        XCTAssertEqual(UserState.Keys.lessonNotes("2026-03", 4, 2), "escuela:2026-03:lecc4:day2:notes")
        XCTAssertEqual(UserState.Keys.lessonLastDay("2026-03", 4), "escuela:2026-03:lecc4:lastDay")
        XCTAssertEqual(UserState.Keys.lessonBookmarks("2026-03"), "escuela:2026-03:bookmarks")
        XCTAssertEqual(UserState.Keys.quiz("leccion-13-gracia-amor-comunion"), "quiz.leccion-13-gracia-amor-comunion.v1")
        XCTAssertEqual(UserState.Keys.hymnRecent, "himnario.recent")
        XCTAssertEqual(UserState.Keys.homePaused, "inicio.videos.pausa")
        XCTAssertEqual(UserState.Keys.bibleBookmarks, "biblia:bookmarks")
        XCTAssertEqual(UserState.Keys.egwBookmarks, "egw:bookmarks")
        XCTAssertEqual(UserState.Keys.contentMode, "contenido.modo")
    }
}
