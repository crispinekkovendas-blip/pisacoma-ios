import Foundation

/**
 The site's quiz-view.tsx state machine, as an immutable value: a pick opens the confirm modal
 (`pending`); confirming locks the answer in `committed`; nothing can change afterwards;
 «Ver resultados» sets `submitted`. Persisted under `quiz.<slug>.v1` as
 `{"committed":{"1":"B"},"submitted":false}`.
 */
struct QuizState: Equatable {
    struct Pending: Equatable { let qN: Int; let letter: String }

    var committed: [Int: String] = [:]
    var submitted: Bool = false
    var pending: Pending? = nil

    var committedCount: Int { committed.count }

    func requestCommit(_ qN: Int, _ letter: String) -> QuizState {
        if committed[qN] != nil || submitted { return self }
        var s = self; s.pending = Pending(qN: qN, letter: letter); return s
    }

    func cancel() -> QuizState { var s = self; s.pending = nil; return s }

    func confirm() -> QuizState {
        guard let p = pending else { return self }
        var s = self
        s.committed[p.qN] = p.letter
        s.pending = nil
        return s
    }

    func submit() -> QuizState { var s = self; s.submitted = true; s.pending = nil; return s }

    func reset() -> QuizState { QuizState() }

    func score(_ pack: QuizPack) -> Int { pack.questions.filter { committed[$0.n] == $0.correct }.count }
    func allCommitted(_ pack: QuizPack) -> Bool { committedCount == pack.questions.count }
    func pct(_ pack: QuizPack) -> Int { pack.questions.isEmpty ? 0 : Int((Double(committedCount) * 100 / Double(pack.questions.count)).rounded()) }

    func toJson() -> String {
        let keys = committed.keys.sorted()
        let inner = keys.map { "\"\($0)\":\"\(committed[$0]!)\"" }.joined(separator: ",")
        return "{\"committed\":{\(inner)},\"submitted\":\(submitted)}"
    }

    /// The site's DEFAULT_LEVELS, used when a pack has none.
    static let defaultLevels = [
        QuizLevel(minScore: 14, name: "Caleb", desc: "¡Excelente! Conoces bien la lección de esta semana."),
        QuizLevel(minScore: 11, name: "Daniel", desc: "Muy buen dominio. Un repaso más y llegas al nivel Caleb."),
        QuizLevel(minScore: 8, name: "Débora", desc: "Vas bien. Vuelve a la lección diaria para afianzar."),
        QuizLevel(minScore: 0, name: "Josías", desc: "Sigue estudiando — cada semana es una nueva oportunidad."),
    ]

    /// Highest minScore reached, like the site's results card.
    static func tier(_ score: Int, _ levels: [QuizLevel]) -> QuizLevel {
        let sorted = levels.sorted { $0.minScore > $1.minScore }
        return sorted.first { score >= $0.minScore } ?? sorted.last!
    }

    static func fromJson(_ raw: String?) -> QuizState {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty, let data = raw.data(using: .utf8),
              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return QuizState() }
        var committed: [Int: String] = [:]
        if let c = o["committed"] as? [String: Any] {
            for (k, v) in c {
                guard let n = Int(k), let letter = v as? String, !letter.isEmpty else { continue }
                committed[n] = letter
            }
        }
        let submitted = (o["submitted"] as? Bool) ?? false
        return QuizState(committed: committed, submitted: submitted, pending: nil)
    }
}
