import Combine
import Foundation
import SwiftUI

/// Site egw/index.tsx FEATURED: the four covers with a badge.
let egwFeatured: Set<String> = ["gc", "pvgm", "hc", "msv"]

/// `egw:bookmarks` entries, as the site writes them.
struct EgwBookmark: Codable, Equatable, Identifiable {
    let slug: String
    let bookId: String
    let bookTitle: String
    let chapter: Int
    let chapterTitle: String
    let addedAt: Int64
    var id: String { "\(slug):\(chapter)" }
}

/// Reading progress of one book (site stats[slug]).
struct BookStats: Equatable {
    let done: Int
    let lastCh: Int?
    var hasProgress: Bool { done > 0 || lastCh != nil }
}

struct Rail: Equatable, Identifiable {
    let aisle: EgwAisle
    let books: [EgwBookMeta]
    var id: String { aisle.roman }
}

struct CatalogUi: Equatable {
    var rails: [Rail] = []
    var stats: [String: BookStats] = [:]
    var books: [EgwBookMeta] { rails.flatMap(\.books) }
    var totalChapters: Int { books.reduce(0) { $0 + $1.chapters } }
    var totalDone: Int { stats.values.reduce(0) { $0 + $1.done } }
    var overallPct: Int { totalChapters == 0 ? 0 : Int((Double(totalDone) * 100 / Double(totalChapters)).rounded()) }
}

@MainActor
final class EgwCatalogModel: ObservableObject {
    @Published private(set) var state = CatalogUi()
    private let app: AppModel
    private var token: AnyObject?

    init(app: AppModel) {
        self.app = app
        refresh()
        token = app.userState.onChange { [weak self] key in
            if key.hasPrefix("egw:") { Task { @MainActor in self?.refresh() } }
        }
    }

    func refresh() {
        Task {
            do {
                let rails = try await app.egw.rails().map { Rail(aisle: $0.0, books: $0.1) }
                var stats: [String: BookStats] = [:]
                for b in rails.flatMap(\.books) {
                    let done = (1...max(1, b.chapters)).filter { app.userState.string(UserState.Keys.egwDone(b.slug, $0)) != nil }.count
                    let last = app.userState.string(UserState.Keys.egwLast(b.slug)).flatMap { Int($0) }
                    stats[b.slug] = BookStats(done: b.chapters == 0 ? 0 : done, lastCh: last)
                }
                state = CatalogUi(rails: rails, stats: stats)
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch {}
        }
    }
}

struct BookUi: Equatable {
    var meta: EgwBookMeta? = nil
    var book: EgwBook? = nil
    var chapter = 1
    var done: Set<Int> = []
    var hasNotes: Set<Int> = []
    var bookmarks: [EgwBookmark] = []
    var notes = ""
    var savedAt: Int64? = nil
    var scale: CGFloat = TextScale.default
    var notFound = false

    var total: Int { book?.chapters.count ?? 0 }
    var current: EgwChapter? { book?.chapters.first { $0.number == chapter } }
    var completedCount: Int { done.count }
    var pct: Int { total == 0 ? 0 : Int((Double(completedCount) * 100 / Double(total)).rounded()) }
    var isDone: Bool { done.contains(chapter) }
    var isBookmarked: Bool { bookmarks.contains { $0.slug == meta?.slug && $0.chapter == chapter } }
}

/// Site egw/[slug]/index.tsx: chapter from `?ch=`, else the last read; done/notes/bookmarks under the site's keys.
@MainActor
final class EgwBookModel: ObservableObject {
    @Published private(set) var state = BookUi()
    private let app: AppModel
    private let slug: String

    init(app: AppModel, slug: String, initialChapter: Int?) {
        self.app = app
        self.slug = slug
        Task {
            do {
                guard let meta = try await app.egw.meta(slug), let book = try await app.egw.book(slug) else { state.notFound = true; return }
                let numbers = book.chapters.map(\.number)
                let wanted = initialChapter ?? app.userState.string(UserState.Keys.egwLast(slug)).flatMap { Int($0) }
                let ch = (wanted.map { numbers.contains($0) } ?? false) ? wanted! : (numbers.first ?? 1)
                let us = app.userState
                state.meta = meta
                state.book = book
                state.chapter = ch
                state.done = Set(numbers.filter { us.string(UserState.Keys.egwDone(slug, $0)) != nil })
                state.hasNotes = Set(numbers.filter { !(us.string(UserState.Keys.egwNotes(slug, $0)) ?? "").isEmpty })
                state.bookmarks = readBookmarks()
                state.notes = us.string(UserState.Keys.egwNotes(slug, ch)) ?? ""
                us.set(UserState.Keys.egwLast(slug), String(ch))
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch {
                state.notFound = true
            }
        }
    }

    private func readBookmarks() -> [EgwBookmark] {
        guard let raw = app.userState.string(UserState.Keys.egwBookmarks), let data = raw.data(using: .utf8) else { return [] }
        return (try? AppJson.decode([EgwBookmark].self, data)) ?? []
    }

    private func writeBookmarks(_ list: [EgwBookmark]) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? enc.encode(list), let s = String(data: data, encoding: .utf8) { app.userState.set(UserState.Keys.egwBookmarks, s) }
        state.bookmarks = list
    }

    func open(_ ch: Int) {
        guard let book = state.book, book.chapters.contains(where: { $0.number == ch }) else { return }
        state.chapter = ch
        state.notes = app.userState.string(UserState.Keys.egwNotes(slug, ch)) ?? ""
        state.savedAt = nil
        app.userState.set(UserState.Keys.egwLast(slug), String(ch))
    }

    func prev() { open(state.chapter - 1) }
    func next() { open(state.chapter + 1) }

    func toggleDone() {
        let ch = state.chapter
        let key = UserState.Keys.egwDone(slug, ch)
        if state.done.contains(ch) { app.userState.set(key, nil); state.done.remove(ch) }
        else { app.userState.set(key, String(Int64(Date().timeIntervalSince1970 * 1000))); state.done.insert(ch) }
    }

    func toggleBookmark() {
        guard let meta = state.meta, let cur = state.current else { return }
        let next: [EgwBookmark] = state.isBookmarked
            ? state.bookmarks.filter { !($0.slug == slug && $0.chapter == state.chapter) }
            : [EgwBookmark(slug: slug, bookId: meta.id, bookTitle: meta.title, chapter: state.chapter, chapterTitle: cur.title, addedAt: Int64(Date().timeIntervalSince1970 * 1000))] + state.bookmarks
        writeBookmarks(next)
    }

    func removeBookmark(_ bmSlug: String, _ chapter: Int) { writeBookmarks(state.bookmarks.filter { !($0.slug == bmSlug && $0.chapter == chapter) }) }

    func notes(_ value: String) {
        let ch = state.chapter
        let blank = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        app.userState.set(UserState.Keys.egwNotes(slug, ch), blank ? nil : value)
        state.notes = value
        if blank { state.hasNotes.remove(ch) } else { state.hasNotes.insert(ch) }
        state.savedAt = blank ? nil : Int64(Date().timeIntervalSince1970 * 1000)
    }

    func clearNotes() { notes("") }
    func smaller() { state.scale = TextScale.smaller(state.scale) }
    func larger() { state.scale = TextScale.larger(state.scale) }

    /// The site's «Reiniciar progreso» in the drawer: clears every done mark of this book.
    func resetProgress() {
        guard let book = state.book else { return }
        for c in book.chapters { app.userState.set(UserState.Keys.egwDone(slug, c.number), nil) }
        state.done = []
    }
}
