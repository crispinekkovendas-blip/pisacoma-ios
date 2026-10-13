import Foundation

/**
 One destination per site route, with the site's path shapes (including the query strings the
 site's own links carry: `/biblia/?libro=43&cap=3&v=16`, `/egw/cc/?ch=2`,
 `/escuela-sabatica/4/?dia=2`) so a universal link or a bundled href maps one to one.
 */
enum Route: Hashable {
    case home
    case visitanos
    case himnario
    case hymn(variant: String, number: Int)
    case videos
    case video(id: String)
    case escuela
    case leccion(number: Int, day: Int?)
    case biblia(book: Int?, chapter: Int?, verse: Int?)
    case diccionario
    case egw
    case egwBook(slug: String, chapter: Int?)
    case quiz
    case quizPack(slug: String)
    case quien
    case buscar
    /// App-only: what to keep on the phone (the first open's mandatory choice, later the menu's «Descargas»).
    case descargas

    var path: String {
        switch self {
        case .home: return "/"
        case .visitanos: return "/visitanos"
        case .himnario: return "/himnario"
        case let .hymn(variant, number): return "/himnario/\(variant)/\(number)"
        case .videos: return "/videos"
        case let .video(id): return "/videos/\(id)"
        case .escuela: return "/escuela-sabatica"
        case let .leccion(number, day): return "/escuela-sabatica/\(number)" + (day.map { "?dia=\($0)" } ?? "")
        case let .biblia(book, chapter, verse):
            guard let book else { return "/biblia" }
            return "/biblia?libro=\(book)&cap=\(chapter ?? 1)" + (verse.map { "&v=\($0)" } ?? "")
        case .diccionario: return "/diccionario"
        case .egw: return "/egw"
        case let .egwBook(slug, chapter): return "/egw/\(slug)" + (chapter.map { "?ch=\($0)" } ?? "")
        case .quiz: return "/quiz"
        case let .quizPack(slug): return "/quiz/\(slug)"
        case .quien: return "/quien"
        case .buscar: return "/buscar"
        case .descargas: return "/descargas"
        }
    }

    /// The path without its query string, for "is this section active" checks.
    var base: String { String(path.split(separator: "?", maxSplits: 1).first ?? "") }

    /// The look the site gives this route (dark on quiz / quien / videos, Pampa on the home).
    var skin: Skin {
        switch self {
        case .home: return .home
        case .videos, .video, .quiz, .quizPack, .quien: return .dark
        default: return .pastel
        }
    }

    /// Parses a site path (from a universal link or a bundled href) into a route, or nil.
    static func parse(_ href: String) -> Route? {
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        let parts2 = trimmed.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let query = parts2.count > 1 ? parts2[1] : ""
        var q: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { q[kv[0]] = kv[1] }
        }
        func int(_ k: String) -> Int? { q[k].flatMap { Int($0) } }
        var p = parts2[0]
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        if p.isEmpty { p = "/" }
        let parts = p.hasPrefix("/") ? String(p.dropFirst()).split(separator: "/").map(String.init) : p.split(separator: "/").map(String.init)
        switch true {
        case p == "/": return .home
        case p == "/visitanos": return .visitanos
        case p == "/himnario": return .himnario
        case parts.count == 3 && parts[0] == "himnario": return Int(parts[2]).map { .hymn(variant: parts[1], number: $0) }
        case p == "/videos": return .videos
        case parts.count == 2 && parts[0] == "videos": return .video(id: parts[1])
        case p == "/escuela-sabatica": return .escuela
        case parts.count == 2 && parts[0] == "escuela-sabatica": return Int(parts[1]).map { .leccion(number: $0, day: int("dia")) }
        case p == "/biblia": return .biblia(book: int("libro"), chapter: int("cap"), verse: int("v"))
        case p == "/diccionario": return .diccionario
        case p == "/egw": return .egw
        case parts.count == 2 && parts[0] == "egw": return .egwBook(slug: parts[1], chapter: int("ch"))
        case p == "/quiz": return .quiz
        case parts.count == 2 && parts[0] == "quiz": return .quizPack(slug: parts[1])
        case p == "/quien": return .quien
        case p == "/buscar": return .buscar
        case p == "/descargas": return .descargas
        default: return nil
        }
    }

    /// A universal link `https://quiz-qwik.vercel.app/<path>?<query>` → route.
    static func parse(url: URL) -> Route? {
        let path = url.path.isEmpty ? "/" : url.path
        return parse(path + (url.query.map { "?\($0)" } ?? ""))
    }
}

/// The site's menu (layout.tsx NAV), in order.
struct NavItem: Identifiable {
    let route: Route
    let label: String
    let desc: String
    let icon: String
    var id: String { label }
}

let navItems: [NavItem] = [
    NavItem(route: .home, label: "Inicio", desc: "Hub principal", icon: "ic_nav_home"),
    NavItem(route: .visitanos, label: "Visítanos", desc: "Horarios · cómo llegar", icon: "ic_nav_pin"),
    NavItem(route: .himnario, label: "Himnario", desc: "1.823 himnos · audio", icon: "ic_nav_music"),
    NavItem(route: .videos, label: "Videos", desc: "Catálogo · Sermones", icon: "ic_nav_video"),
    NavItem(route: .escuela, label: "Esc. Sabática", desc: "", icon: "ic_nav_book"), // desc = quarterLabel(now)
    NavItem(route: .biblia(book: nil, chapter: nil, verse: nil), label: "Biblia", desc: "Reina-Valera 1960", icon: "ic_nav_cross"),
    NavItem(route: .diccionario, label: "Diccionario", desc: "Términos · Wiktionary", icon: "ic_nav_dict"),
    NavItem(route: .egw, label: "EGW", desc: "25 libros · 4 pasillos", icon: "ic_nav_feather"),
    NavItem(route: .quiz, label: "Quiz", desc: "Lección de la semana", icon: "ic_nav_target"),
    NavItem(route: .quien, label: "¿Quién?", desc: "Ruleta de nombres", icon: "ic_nav_spinner"),
    NavItem(route: .buscar, label: "Buscar", desc: "Himnos · EGW · Biblia · lecciones", icon: "ic_nav_search"),
]

/// layout.tsx quarterLabel: "Trimestre 2026·Q4" in Peru time (UTC−5 all year).
func quarterLabel(_ nowUtcMillis: Int64) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let lima = Date(timeIntervalSince1970: Double(nowUtcMillis - 5 * 3_600_000) / 1000)
    let comps = cal.dateComponents([.year, .month], from: lima)
    let q = (comps.month! - 1) / 3 + 1
    return "Trimestre \(comps.year!)·Q\(q)"
}
