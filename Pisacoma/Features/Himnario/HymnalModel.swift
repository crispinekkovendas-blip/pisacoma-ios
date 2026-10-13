import Combine
import Foundation

/// A row of the hymnal index (site himnario/index.tsx Row).
struct HymnRow: Equatable, Identifiable {
    let number: Int
    let title: String
    let bibleRef: String?
    var id: Int { number }
}

/// The site's utils/recent-hymns.ts: last six hymns opened, newest first, under `himnario.recent`.
struct RecentHymn: Codable, Equatable, Identifiable {
    let variant: String
    let number: Int
    let title: String
    let ts: Int64
    var id: String { "\(variant)/\(number)" }
}

enum RecentHymns {
    static let max = 6

    static func read(_ state: UserState) -> [RecentHymn] {
        guard let raw = state.string(UserState.Keys.hymnRecent), let data = raw.data(using: .utf8) else { return [] }
        return (try? AppJson.decode([RecentHymn].self, data)) ?? []
    }

    static func push(_ state: UserState, variant: String, number: Int, title: String, now: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        var list = read(state).filter { !($0.variant == variant && $0.number == number) }
        list.insert(RecentHymn(variant: variant, number: number, title: title, ts: now), at: 0)
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? enc.encode(Array(list.prefix(max))), let s = String(data: data, encoding: .utf8) { state.set(UserState.Keys.hymnRecent, s) }
    }
}

struct HymnalUi: Equatable {
    var variant: HymnVariant = .es
    var query = ""
    /// Every row of the active hymnal, deduplicated by number (NHA has 587 twice).
    var rows: [HymnRow] = []
    var featured: [HymnRow] = []
    var recent: [RecentHymn] = []
    var loading = true

    static let rangeSize = 100

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The site's filter: number, title or Bible reference contains the query.
    var filtered: [HymnRow] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return rows }
        let qNum = Int(q)
        return rows.filter { r in
            r.title.lowercased().contains(q) || (qNum != nil && r.number == qNum) || (r.bibleRef?.lowercased().contains(q) == true)
        }
    }

    /// Ranges of 100 for the «Ir a» chips and the list breaks.
    var ranges: [ClosedRange<Int>] {
        guard let max = rows.last?.number else { return [] }
        return stride(from: 1, through: max, by: Self.rangeSize).map { s in s...min(s + Self.rangeSize - 1, max) }
    }

    var recentForVariant: [RecentHymn] { Array(recent.filter { $0.variant == variant.slug }.prefix(3)) }
}

@MainActor
final class HymnalModel: ObservableObject {
    @Published var state = HymnalUi()
    private let app: AppModel

    init(app: AppModel) {
        self.app = app
        select(.es)
    }

    func select(_ variant: HymnVariant) {
        state.variant = variant
        state.query = ""
        state.loading = true
        Task {
            do {
                var seen = Set<Int>()
                let rows = try await app.hymns.all(variant).compactMap { h -> HymnRow? in seen.insert(h.number).inserted ? HymnRow(number: h.number, title: h.title, bibleRef: h.bibleReference) : nil }
                let byNum = Dictionary(rows.map { ($0.number, $0) }, uniquingKeysWith: { a, _ in a })
                let featured = try await app.hymns.featured(variant).compactMap { byNum[$0] }
                state.rows = rows
                state.featured = featured
                state.recent = RecentHymns.read(app.userState)
                state.loading = false
            } catch let e as ContentMissing {
                state.loading = false
                ContentErrors.report(e, app: app)
            } catch {
                state.loading = false
            }
        }
    }

    func query(_ q: String) { state.query = q }

    func refreshRecent() { state.recent = RecentHymns.read(app.userState) }
}
