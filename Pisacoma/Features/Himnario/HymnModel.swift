import Combine
import Foundation

/// One screen of «Proyectar» (site hymn-projector ProjectorSlide).
struct ProjectorSlide: Equatable, Identifiable {
    let label: String
    let lines: [String]
    var isChorus: Bool { label.hasPrefix("Coro") }
    var id: String { label + lines.joined(separator: "|") }
}

enum HymnUi: Equatable {
    case loading
    case notFound
    case ready(hymn: Hymn, slides: [ProjectorSlide], hasNext: Bool)
}

@MainActor
final class HymnModel: ObservableObject {
    @Published private(set) var state: HymnUi = .loading
    private let app: AppModel

    init(app: AppModel, variant: String, number: Int) {
        self.app = app
        Task {
            do {
                guard let v = HymnVariant.fromSlug(variant), let h = try await app.hymns.get(v, number) else { state = .notFound; return }
                let next = try await app.hymns.get(v, number + 1) != nil
                state = .ready(hymn: h, slides: Self.buildSlides(h.blocks), hasNext: next)
                RecentHymns.push(app.userState, variant: variant, number: number, title: h.title) // site RecordVisit
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch {
                state = .notFound
            }
        }
    }

    /// Site hymn page rawSlides + splitLong: one screen per stanza, the chorus repeated after each.
    static func buildSlides(_ blocks: [LyricBlock]) -> [ProjectorSlide] { splitLong(rawSlides(blocks)) }

    private static func rawSlides(_ blocks: [LyricBlock]) -> [ProjectorSlide] {
        let choruses = blocks.filter { $0.isChorus }
        let stanzas = blocks.filter { !$0.isChorus }
        if choruses.count == 1 && !stanzas.isEmpty {
            return stanzas.enumerated().flatMap { i, b in [ProjectorSlide(label: "Estrofa \(b.stanzaNumber ?? (i + 1))", lines: b.lines), ProjectorSlide(label: "Coro", lines: choruses[0].lines)] }
        }
        var n = 0
        return blocks.map { b in
            if b.isChorus { return ProjectorSlide(label: "Coro", lines: b.lines) }
            n += 1
            return ProjectorSlide(label: "Estrofa \(b.stanzaNumber ?? n)", lines: b.lines)
        }
    }

    /// Blocks longer than 12 lines don't fit a phone: split them into ≤ 8-line parts.
    private static func splitLong(_ slides: [ProjectorSlide]) -> [ProjectorSlide] {
        slides.flatMap { sl -> [ProjectorSlide] in
            if sl.lines.count <= 12 { return [sl] }
            let parts = (sl.lines.count + 7) / 8
            let size = (sl.lines.count + parts - 1) / parts
            return (0..<parts).map { i in ProjectorSlide(label: "\(sl.label) · \(i + 1)/\(parts)", lines: Array(sl.lines.dropFirst(i * size).prefix(size))) }
        }
    }
}
