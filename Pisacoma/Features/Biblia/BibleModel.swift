import Combine
import Foundation
import SwiftUI

/// `biblia:bookmarks` entries, as the site writes them.
struct BibleBookmark: Codable, Equatable, Identifiable {
    let bookNum: Int
    let chapter: Int
    let bookName: String
    let addedAt: Int64
    var id: String { "\(bookNum):\(chapter)" }
}

/// `biblia:recent` entries (max 20), as the site writes them.
struct RecentChapter: Codable, Equatable, Identifiable {
    let bookNum: Int
    let chapter: Int
    let bookName: String
    let viewedAt: Int64
    var id: String { "\(bookNum):\(chapter)" }
}

struct Verse: Equatable, Identifiable {
    let n: Int
    let text: String
    var id: Int { n }
}

struct BibleUi: Equatable {
    var books: [BibleBook] = []
    var bookNum = 43
    var chapter = 3
    var verses: [Verse] = []
    var loading = true
    var targetVerse = 0
    var scale: CGFloat = 1.05
    var bookmarks: [BibleBookmark] = []
    var recent: [RecentChapter] = []
    /// "book:chapter" keys that have notes (`biblia:hasNotesIndex`).
    var hasNotes: [String] = []
    var notes = ""
    var savedAt: Int64? = nil

    var book: BibleBook? { books.first { $0.num == bookNum } }
    var isBookmarked: Bool { bookmarks.contains { $0.bookNum == bookNum && $0.chapter == chapter } }
    var currentHasNotes: Bool { hasNotes.contains("\(bookNum):\(chapter)") }
    var isFirst: Bool { bookNum == 1 && chapter == 1 }
    var isLast: Bool { bookNum == 66 && chapter == (book?.chapters ?? 1) }
}

/// The site's biblia/index.tsx state: book/chapter, deep-link verse, notes, bookmarks, recents.
@MainActor
final class BibleModel: ObservableObject {
    @Published private(set) var state: BibleUi
    private let app: AppModel

    init(app: AppModel, book: Int?, chapter: Int?, verse: Int?) {
        self.app = app
        state = BibleUi(targetVerse: verse ?? 0)
        Task {
            do {
                let books = try await app.bible.books()
                let b = min(max(book ?? 43, 1), 66)
                let max = books.first { $0.num == b }?.chapters ?? 1
                let c = min(Swift.max(chapter ?? (b == 43 ? 3 : 1), 1), max)
                state.books = books
                state.bookNum = b
                state.chapter = c
                state.bookmarks = readList(UserState.Keys.bibleBookmarks)
                state.recent = readList(UserState.Keys.bibleRecent)
                state.hasNotes = app.userState.stringList(UserState.Keys.bibleHasNotesIndex)
                open(b, c, keepTarget: true)
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch {}
        }
    }

    private func readList<T: Decodable>(_ key: String) -> [T] {
        guard let raw = app.userState.string(key), let data = raw.data(using: .utf8) else { return [] }
        return (try? AppJson.decode([T].self, data)) ?? []
    }

    private func write<T: Encodable>(_ key: String, _ list: [T]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? enc.encode(list), let s = String(data: data, encoding: .utf8) { app.userState.set(key, s) }
    }

    func open(_ bookNum: Int, _ chapter: Int, keepTarget: Bool = false) {
        state.bookNum = bookNum
        state.chapter = chapter
        state.loading = true
        if !keepTarget { state.targetVerse = 0 }
        state.savedAt = nil
        Task {
            do {
                let verses = try await app.bible.verses(bookNum, chapter, 1, 999).map { Verse(n: $0.0, text: $0.1) }
                let name = state.books.first { $0.num == bookNum }?.name ?? ""
                // recent (max 20, newest first) — site useVisibleTask on book/chapter
                let recent = Array(([RecentChapter(bookNum: bookNum, chapter: chapter, bookName: name, viewedAt: Int64(Date().timeIntervalSince1970 * 1000))] + state.recent.filter { !($0.bookNum == bookNum && $0.chapter == chapter) }).prefix(20))
                write(UserState.Keys.bibleRecent, recent)
                state.verses = verses
                state.loading = false
                state.recent = recent
                state.notes = app.userState.string(UserState.Keys.bibleNotes(bookNum, chapter)) ?? ""
            } catch let e as ContentMissing {
                state.loading = false
                ContentErrors.report(e, app: app)
            } catch {
                state.loading = false
            }
        }
    }

    func prev() {
        let s = state
        if s.chapter > 1 { open(s.bookNum, s.chapter - 1) }
        else if s.bookNum > 1 { open(s.bookNum - 1, s.books.first { $0.num == s.bookNum - 1 }?.chapters ?? 1) }
    }

    func next() {
        let s = state
        let max = s.book?.chapters ?? 1
        if s.chapter < max { open(s.bookNum, s.chapter + 1) }
        else if s.bookNum < 66 { open(s.bookNum + 1, 1) }
    }

    /// Tapping a verse selects it (for sharing) or clears the selection.
    func tapVerse(_ v: Int) { state.targetVerse = state.targetVerse == v ? 0 : v }

    func smaller() { state.scale = max(0.9, state.scale - 0.08) }
    func larger() { state.scale = min(1.5, state.scale + 0.08) }

    func toggleBookmark() {
        let s = state
        let next: [BibleBookmark] = s.isBookmarked
            ? s.bookmarks.filter { !($0.bookNum == s.bookNum && $0.chapter == s.chapter) }
            : [BibleBookmark(bookNum: s.bookNum, chapter: s.chapter, bookName: s.book?.name ?? "", addedAt: Int64(Date().timeIntervalSince1970 * 1000))] + s.bookmarks
        write(UserState.Keys.bibleBookmarks, next)
        state.bookmarks = next
    }

    func removeBookmark(_ bookNum: Int, _ chapter: Int) {
        let next = state.bookmarks.filter { !($0.bookNum == bookNum && $0.chapter == chapter) }
        write(UserState.Keys.bibleBookmarks, next)
        state.bookmarks = next
    }

    func notes(_ value: String) {
        let s = state
        let key = "\(s.bookNum):\(s.chapter)"
        let blank = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let idx = blank ? s.hasNotes.filter { $0 != key } : (s.hasNotes.contains(key) ? s.hasNotes : s.hasNotes + [key])
        app.userState.set(UserState.Keys.bibleNotes(s.bookNum, s.chapter), blank ? nil : value)
        app.userState.set(UserState.Keys.bibleHasNotesIndex, idx)
        state.notes = value
        state.hasNotes = idx
        state.savedAt = blank ? nil : Int64(Date().timeIntervalSince1970 * 1000)
    }

    func clearNotes() { notes("") }

    func aymaraUrl() -> String { app.bible.aymaraUrl(state.bookNum, state.chapter) }
}
