import Foundation

struct Definition: Equatable, Hashable { let definition: String; let examples: [String] }
struct DictSection: Equatable, Hashable { let partOfSpeech: String; let language: String?; let definitions: [Definition] }

enum DictResult: Equatable {
    case found([DictSection])
    case error(String)
}

/// The site's diccionario route: es.wiktionary.org REST definitions, same section choice and messages.
enum Wiktionary {
    static let networkError = "Error de red. Intenta de nuevo."
    static func notFoundMessage(_ word: String) -> String { "«\(word)» — no encontramos esta palabra en el Wiccionario en español." }
    static func emptyMessage(_ word: String) -> String { "«\(word)» no tiene definiciones registradas." }

    /// Site POPULAR, in order.
    static let suggested = [
        "amor", "fe", "esperanza", "gracia", "salvación", "redención", "justicia", "misericordia", "pacto", "sábado",
        "iglesia", "profeta", "apóstol", "evangelio", "reino", "oración", "arrepentimiento", "perdón", "santificación",
        "bautismo", "alma", "espíritu", "pecado", "verdad", "luz", "alabanza", "adoración", "gloria", "santo", "fiel",
    ]

    static func url(_ word: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        let enc = word.addingPercentEncoding(withAllowedCharacters: allowed) ?? word
        return "https://es.wiktionary.org/api/rest_v1/page/definition/" + enc
    }

    private static let tags = try! NSRegularExpression(pattern: "<[^>]+>")
    private static func strip(_ s: String) -> String {
        tags.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
            .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `es` | `Spanish` | the first language; empty on anything unexpected.
    static func parse(_ body: String) -> [DictSection] {
        guard let data = body.data(using: .utf8), let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        let arr: [[String: Any]]
        if let es = root["es"] as? [[String: Any]] { arr = es }
        else if let sp = root["Spanish"] as? [[String: Any]] { arr = sp }
        else if let first = root.values.first(where: { $0 is [[String: Any]] }) as? [[String: Any]] { arr = first }
        else { return [] }
        return arr.map { o in
            DictSection(
                partOfSpeech: o["partOfSpeech"] as? String ?? "",
                language: o["language"] as? String,
                definitions: (o["definitions"] as? [[String: Any]] ?? []).map { d in
                    Definition(definition: strip(d["definition"] as? String ?? ""), examples: (d["examples"] as? [String] ?? []).map(strip))
                }
            )
        }
    }

    static func lookup(_ word: String) async -> DictResult {
        let w = word.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            let sections = parse(try await Http.get(url(w)))
            return sections.isEmpty ? .error(emptyMessage(w)) : .found(sections)
        } catch let e as Http.Status {
            return .error(e.code == 404 ? notFoundMessage(w) : networkError)
        } catch {
            return .error(networkError)
        }
    }
}
