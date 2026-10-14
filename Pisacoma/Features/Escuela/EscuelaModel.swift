import Combine
import Foundation
import SwiftUI

let dayLabels = ["Sábado", "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes"]
let dayShort = ["Sáb", "Dom", "Lun", "Mar", "Mié", "Jue", "Vie"]

/// Site [leccion]/index.tsx ACCENTS: one muted accent per lesson.
let lessonAccents: [Color] = [
    0x5A7C3A, 0x6C5424, 0x4D6F33, 0x7A6633, 0x8A5A3A,
    0x506E35, 0x4A6741, 0x7C4F3A, 0x5D7333, 0x85702D,
    0x6F5F2C, 0x3F6238, 0xA06B3A,
].map { Color(hex: $0) }

/// `escuela:<QID>:bookmarks` entries, as the site writes them.
struct LessonBookmark: Codable, Equatable, Identifiable {
    let leccionN: Int
    let title: String
    let addedAt: Int64
    var id: Int { leccionN }
}

struct QuarterUi: Equatable {
    var quarterly: Quarterly? = nil
    var currentIdx = 0
    var ended = false
    var nextStartLabel = ""
    /// completed day count per lesson number
    var progress: [Int: Int] = [:]
}

private func progressMap(_ q: Quarterly, _ userState: UserState) -> [Int: Int] {
    Dictionary(uniqueKeysWithValues: q.lessons.map { l in (l.number, (0..<l.days.count).filter { d in userState.string(UserState.Keys.lessonDone(q.id, l.number, d)) != nil }.count) })
}

@MainActor
final class QuarterModel: ObservableObject {
    @Published private(set) var state = QuarterUi()
    private let app: AppModel
    private var token: AnyObject?

    init(app: AppModel) {
        self.app = app
        refresh()
        token = app.userState.onChange { [weak self] key in
            if key.hasPrefix("escuela:") { Task { @MainActor in self?.refresh() } }
        }
    }

    func refresh() {
        Task {
            do {
                let q = try await app.quarterly.quarterly()
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                let status = Zmanim.quarterStatus(Zmanim.QuarterDates(startDate: q.startDate, endDate: q.endDate), now)
                state = QuarterUi(
                    quarterly: q,
                    currentIdx: Zmanim.currentLessonIndex(q.lessons.map(\.startDate), now),
                    ended: status.state == .ended,
                    nextStartLabel: Zmanim.longDayLabel(status.nextStart),
                    progress: progressMap(q, app.userState)
                )
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch {}
        }
    }
}

struct DayView: Equatable {
    let title: String
    let blocks: [MdBlock]
}

struct LessonUi: Equatable {
    var quarterly: Quarterly? = nil
    var number = 0
    var days: [DayView] = []
    var activeDay = 0
    var doneDays: Set<Int> = []
    var daysWithNotes: Set<Int> = []
    var bookmarks: [LessonBookmark] = []
    var progress: [Int: Int] = [:]
    var notes = ""
    var savedAt: Int64? = nil
    var scale: CGFloat = TextScale.default
    var quizSlug: String? = nil
    var notFound = false

    var lesson: Lesson? { quarterly?.lessons.first { $0.number == number } }
    var totalDays: Int { days.count }
    var completedCount: Int { doneDays.count }
    var pct: Int { totalDays == 0 ? 0 : Int((Double(completedCount) * 100 / Double(totalDays)).rounded()) }
    var isDone: Bool { doneDays.contains(activeDay) }
    var isBookmarked: Bool { bookmarks.contains { $0.leccionN == number } }
}

@MainActor
final class LessonModel: ObservableObject {
    @Published private(set) var state: LessonUi
    private let app: AppModel
    private let number: Int
    private var qid = ""

    init(app: AppModel, number: Int, initialDay: Int?) {
        self.app = app
        self.number = number
        state = LessonUi(number: number)
        Task {
            do {
                let q = try await app.quarterly.quarterly()
                qid = q.id
                guard let lesson = q.lessons.first(where: { $0.number == number }) else { state.notFound = true; return }
                let days = lesson.days.map { d -> DayView in let p = LessonMarkdown.parseDay(d.content); return DayView(title: p.title, blocks: LessonMarkdown.parse(p.body)) }
                let last = initialDay ?? app.userState.string(UserState.Keys.lessonLastDay(qid, number)).flatMap { Int($0) }
                let active = (last.map { days.indices.contains($0) } ?? false) ? last! : 0
                let us = app.userState
                state.quarterly = q
                state.days = days
                state.activeDay = active
                state.doneDays = Set(days.indices.filter { d in us.string(UserState.Keys.lessonDone(qid, number, d)) != nil })
                state.daysWithNotes = Set(days.indices.filter { d in !(us.string(UserState.Keys.lessonNotes(qid, number, d)) ?? "").isEmpty })
                state.bookmarks = readBookmarks()
                state.progress = progressMap(q, us)
                state.notes = us.string(UserState.Keys.lessonNotes(qid, number, active)) ?? ""
                state.quizSlug = try? await app.quizzes.forLesson(number)?.slug
                us.set(UserState.Keys.lessonLastDay(qid, number), String(active))
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch {
                state.notFound = true
            }
        }
    }

    private func readBookmarks() -> [LessonBookmark] {
        guard let raw = app.userState.string(UserState.Keys.lessonBookmarks(qid)), let data = raw.data(using: .utf8) else { return [] }
        return (try? AppJson.decode([LessonBookmark].self, data)) ?? []
    }

    private func writeBookmarks(_ list: [LessonBookmark]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? enc.encode(list), let s = String(data: data, encoding: .utf8) { app.userState.set(UserState.Keys.lessonBookmarks(qid), s) }
        state.bookmarks = list
    }

    func selectDay(_ d: Int) {
        guard state.days.indices.contains(d) else { return }
        state.activeDay = d
        state.notes = app.userState.string(UserState.Keys.lessonNotes(qid, number, d)) ?? ""
        state.savedAt = nil
        app.userState.set(UserState.Keys.lessonLastDay(qid, number), String(d))
    }

    func toggleDone() {
        let d = state.activeDay
        let key = UserState.Keys.lessonDone(qid, number, d)
        if state.doneDays.contains(d) {
            app.userState.set(key, nil)
            state.doneDays.remove(d)
        } else {
            app.userState.set(key, String(Int64(Date().timeIntervalSince1970 * 1000)))
            state.doneDays.insert(d)
        }
        state.progress[number] = state.doneDays.count
    }

    func toggleBookmark() {
        let next: [LessonBookmark] = state.isBookmarked
            ? state.bookmarks.filter { $0.leccionN != number }
            : [LessonBookmark(leccionN: number, title: state.lesson?.title ?? "", addedAt: Int64(Date().timeIntervalSince1970 * 1000))] + state.bookmarks
        writeBookmarks(next)
    }

    func removeBookmark(_ leccionN: Int) { writeBookmarks(state.bookmarks.filter { $0.leccionN != leccionN }) }

    func notes(_ value: String) {
        let d = state.activeDay
        let key = UserState.Keys.lessonNotes(qid, number, d)
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            app.userState.set(key, nil)
            state.notes = value
            state.daysWithNotes.remove(d)
            state.savedAt = nil
        } else {
            app.userState.set(key, value)
            state.notes = value
            state.daysWithNotes.insert(d)
            state.savedAt = Int64(Date().timeIntervalSince1970 * 1000)
        }
    }

    func clearNotes() { notes("") }
    func smaller() { state.scale = TextScale.smaller(state.scale) }
    func larger() { state.scale = TextScale.larger(state.scale) }
}

/// Site relativeTime: "ahora mismo", "hace 5s", "hace 3 min", "hace 2 h", "hace 4 d".
func relativeTimeEs(_ ms: Int64, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> String {
    let s = max(0, (now - ms) / 1000)
    if s < 5 { return "ahora mismo" }
    if s < 60 { return "hace \(s)s" }
    let m = s / 60
    if m < 60 { return "hace \(m) min" }
    let h = m / 60
    if h < 24 { return "hace \(h) h" }
    return "hace \(h / 24) d"
}
