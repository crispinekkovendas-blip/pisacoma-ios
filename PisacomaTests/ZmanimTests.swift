import XCTest
@testable import Pisacoma

/// Reference values computed with the site's own src/utils/zmanim.ts (see the Android ZmanimTest).
final class ZmanimTests: XCTestCase {
    private let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }()
    private func ms(_ s: String) -> Int64 { Int64(iso.date(from: s)!.timeIntervalSince1970 * 1000) }
    private func assertMinute(_ expected: String, _ actual: Int64?, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(actual, "nil instant", file: file, line: line)
        XCTAssertEqual(ms(expected) / 60_000, (actual ?? 0) / 60_000, file: file, line: line)
    }

    func testSunsetAndSunriseForOneDay() {
        let day = ms("2026-10-16T00:00:00Z")
        assertMinute("2026-10-16T22:37:26Z", Zmanim.sunsetUtc(day))
        assertMinute("2026-10-16T10:08:46Z", Zmanim.sunriseUtc(day))
    }

    func testMidweekPointsToTheComingSabbath() {
        let t = Zmanim.sabbathTimes(ms("2026-10-13T15:00:00Z"))
        XCTAssertEqual(t.friday, ms("2026-10-16T00:00:00Z"))
        XCTAssertEqual(t.saturday, ms("2026-10-17T00:00:00Z"))
        assertMinute("2026-10-16T22:37:26Z", t.start)
        assertMinute("2026-10-17T22:37:40Z", t.end)
        XCTAssertFalse(t.isSabbath)
    }

    func testSaturdayMorningIsSabbath() {
        let t = Zmanim.sabbathTimes(ms("2026-06-20T12:00:00Z"))
        XCTAssertEqual(t.friday, ms("2026-06-19T00:00:00Z"))
        assertMinute("2026-06-19T22:12:18Z", t.start)
        assertMinute("2026-06-20T22:12:30Z", t.end)
        XCTAssertTrue(t.isSabbath)
    }

    func testDecemberSunsetIsLater() {
        let t = Zmanim.sabbathTimes(ms("2026-12-20T12:00:00Z"))
        XCTAssertEqual(t.friday, ms("2026-12-25T00:00:00Z"))
        assertMinute("2026-12-25T23:11:20Z", t.start)
        assertMinute("2026-12-26T23:11:47Z", t.end)
    }

    func testSaturdayAfterSunsetRollsToNextWeek() {
        let t = Zmanim.sabbathTimes(ms("2026-10-17T23:30:00Z"))
        XCTAssertEqual(t.friday, ms("2026-10-23T00:00:00Z"))
        assertMinute("2026-10-23T22:39:20Z", t.start)
        XCTAssertFalse(t.isSabbath)
    }

    func testSaturdayBeforeSunsetIsStillThisSabbath() {
        let t = Zmanim.sabbathTimes(ms("2026-10-17T22:00:00Z"))
        XCTAssertEqual(t.friday, ms("2026-10-16T00:00:00Z"))
        XCTAssertTrue(t.isSabbath)
    }

    func testLocalCivilDateUsesPeruTime() {
        XCTAssertEqual(Zmanim.localCivilDate(ms("2026-10-14T03:00:00Z")), ms("2026-10-13T00:00:00Z"))
    }

    func testClockAndDayLabelsInSpanish() {
        XCTAssertEqual(Zmanim.clock12(ms("2026-10-16T22:37:26Z")), Zmanim.Clock12(time: "5:37", suffix: "PM"))
        XCTAssertEqual(Zmanim.clock12(ms("2026-10-17T05:05:00Z")), Zmanim.Clock12(time: "12:05", suffix: "AM"))
        XCTAssertEqual(Zmanim.clock12(nil), Zmanim.Clock12(time: "--:--", suffix: ""))
        XCTAssertEqual(Zmanim.dayLabel(ms("2026-10-16T00:00:00Z")), "Viernes 16 oct")
        XCTAssertEqual(Zmanim.dayLabel(ms("2026-10-17T00:00:00Z")), "Sábado 17 oct")
        XCTAssertEqual(Zmanim.dayLabel(ms("2026-09-18T00:00:00Z")), "Viernes 18 set")
    }

    func testParseDmy() {
        XCTAssertEqual(Zmanim.parseDMY("27/06/2026"), ms("2026-06-27T00:00:00Z"))
    }

    func testQuarterStatusAgainstPeruDate() {
        let q = Zmanim.QuarterDates(startDate: "27/06/2026", endDate: "25/09/2026")
        XCTAssertEqual(Zmanim.quarterStatus(q, ms("2026-08-01T12:00:00Z")).state, .active)
        XCTAssertEqual(Zmanim.quarterStatus(q, ms("2026-06-20T12:00:00Z")).state, .upcoming)
        let ended = Zmanim.quarterStatus(q, ms("2026-10-13T15:00:00Z"))
        XCTAssertEqual(ended.state, .ended)
        XCTAssertEqual(ended.nextStart, ms("2026-09-26T00:00:00Z"))
        XCTAssertEqual(Zmanim.quarterStatus(q, ms("2026-09-26T04:30:00Z")).state, .active)
    }

    func testCurrentLessonIndexIsLatestStartedLesson() {
        let starts = ["27/06/2026", "04/07/2026", "11/07/2026"]
        XCTAssertEqual(Zmanim.currentLessonIndex(starts, ms("2026-06-20T12:00:00Z")), 0)
        XCTAssertEqual(Zmanim.currentLessonIndex(starts, ms("2026-07-05T12:00:00Z")), 1)
        XCTAssertEqual(Zmanim.currentLessonIndex(starts, ms("2026-12-01T12:00:00Z")), 2)
        XCTAssertEqual(Zmanim.currentLessonIndex(starts, ms("2026-07-11T00:30:00Z")), 1)
    }

    func testLongDayLabel() {
        XCTAssertEqual(Zmanim.longDayLabel(ms("2026-09-26T00:00:00Z")), "sábado 26 de septiembre")
    }
}
