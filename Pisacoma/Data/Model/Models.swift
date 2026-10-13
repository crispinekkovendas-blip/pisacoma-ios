import Foundation

// The site's data shapes (same names as the Android `data/model/*.kt`). Fields the site may omit are optional.

/// One row of the site's bible-books.json. Books 1–39 are the Old Testament.
struct BibleBook: Codable, Equatable, Hashable {
    let num: Int
    let name: String
    let chapters: Int
    let abbr: String
    var isOldTestament: Bool { num <= 39 }
}

// ---- church.json (src/data/church.ts) ----
struct ScheduleItem: Codable, Equatable { let day: String; let time: String; let suffix: String; let name: String }
struct Location: Codable, Equatable { let lat: Double; let lng: Double; let district: String; let province: String; let region: String; let altitude: String }
struct Mission: Codable, Equatable { let name: String; let address: String; let city: String }
struct HierarchyItem: Codable, Equatable { let name: String; let place: String }
struct TimelineItem: Codable, Equatable { let year: String; let text: String }
struct Pioneer: Codable, Equatable { let name: String; let role: String; let bio: String }
struct Church: Codable, Equatable {
    let schedule: [ScheduleItem]
    let location: Location
    let mission: Mission
    let hierarchy: [HierarchyItem]
    let timeline: [TimelineItem]
    let pioneers: [Pioneer]
}

// ---- EGW ----
/// One of the four «pasillos» of the EGW catalogue (site egw/index.tsx AISLES).
struct EgwAisle: Codable, Equatable, Hashable { let roman: String; let label: String; let lede: String }

/// Catalogue row (site egw/index.tsx BOOKS); `cover` is the file name under Content/covers.
struct EgwBookMeta: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let slug: String
    let title: String
    let subtitle: String
    let color: String
    let chapters: Int
    let aisle: String
    let cover: String
}

struct EgwChapter: Codable, Equatable { let number: Int; let title: String; let paragraphs: [String] }

struct EgwBook: Codable, Equatable {
    let id: String
    let title: String
    var subtitle: String?
    var lang: String?
    var color: String?
    let chapters: [EgwChapter]
}

// ---- hymnals ----
/// The three hymnals, by the site's URL slug (`/himnario/<slug>/<n>`).
enum HymnVariant: String, CaseIterable, Codable, Hashable {
    case es, pt, ptNovo = "pt-novo"

    var slug: String { rawValue }
    var file: String {
        switch self {
        case .es: return "himnario-es"
        case .pt: return "himnario-pt"
        case .ptNovo: return "himnario-pt-novo"
        }
    }
    var label: String {
        switch self {
        case .es: return "Himnario Adventista · Español"
        case .pt: return "Hinário Adventista · Português (Antigo)"
        case .ptNovo: return "Novo Hinário Adventista · Português"
        }
    }
    var tabLabel: String {
        switch self {
        case .es: return "Español"
        case .pt: return "PT Antigo"
        case .ptNovo: return "PT Novo"
        }
    }
    var tabSub: String {
        switch self {
        case .es: return "Adventista · 613 himnos"
        case .pt: return "Hinário Antigo · 610"
        case .ptNovo: return "Novo Hinário · 600"
        }
    }
    static func fromSlug(_ slug: String) -> HymnVariant? { HymnVariant(rawValue: slug) }
}

/// One printed block of a hymn: a numbered stanza or the chorus.
struct LyricBlock: Equatable, Hashable {
    let type: String
    let lines: [String]
    var stanzaNumber: Int? = nil
    var isChorus: Bool { type == "chorus" }
}

struct Hymn: Equatable, Hashable, Identifiable {
    let variant: HymnVariant
    let number: Int
    let title: String
    let bibleReference: String?
    let mp3Url: String?
    let mp3UrlInstr: String?
    let ytId: String?
    let blocks: [LyricBlock]
    var id: String { "\(variant.slug)/\(number)" }
}

// ---- Sabbath School quarterly (field names as scraped) ----
struct Quarterly: Codable, Equatable {
    let id: String
    let title: String
    var description: String?
    var humanDate: String?
    let startDate: String
    let endDate: String
    var colorPrimary: String?
    var author: String?
    var introduction: String?
    let lessons: [Lesson]

    enum CodingKeys: String, CodingKey {
        case id, title, description, author, introduction, lessons
        case humanDate = "human_date"
        case startDate = "start_date"
        case endDate = "end_date"
        case colorPrimary = "color_primary"
    }
}

struct Lesson: Codable, Equatable, Identifiable {
    let number: Int
    let title: String
    let startDate: String
    let endDate: String
    let days: [LessonDay]
    var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number, title, days
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

/// `content` is the day's markdown with a `---` front matter (title, date).
struct LessonDay: Codable, Equatable { let day: Int; let content: String }

// ---- quizzes (src/data/quizzes/types.ts) ----
struct QuizOption: Codable, Equatable, Hashable { let letter: String; let text: String }
struct QuizQuestion: Codable, Equatable, Hashable {
    let n: Int
    let text: String
    var ref: String?
    let options: [QuizOption]
    let correct: String
    var explain: String?
}
struct QuizLevel: Codable, Equatable, Hashable { let minScore: Int; let name: String; let desc: String }
struct Memorize: Codable, Equatable, Hashable { let text: String; let ref: String }
struct QuizPack: Codable, Equatable, Hashable, Identifiable {
    let slug: String
    let lessonNumber: Int
    let title: String
    let badge: String
    let subtitle: String
    let memorize: Memorize
    var metaTitle: String?
    var metaDescription: String?
    let questions: [QuizQuestion]
    var levels: [QuizLevel]?
    var id: String { slug }
}

// ---- search index (utils/search.ts SearchIndex) ----
struct SearchIndex: Equatable {
    struct Quarter: Equatable { let id: String; let title: String }
    /// variant, number, title, first line of stanza 1 / of the chorus when they differ from the title
    struct HymnRow: Equatable { let variant: String; let number: Int; let title: String; let lines: [String] }
    struct EgwChapterRef: Equatable { let number: Int; let title: String }
    struct EgwRow: Equatable { let s: String; let t: String; let c: [EgwChapterRef] }
    struct LessonRow: Equatable { let n: Int; let t: String; let d: [String] }
    struct BibleRow: Equatable { let num: Int; let name: String; let chapters: Int; let abbr: String }

    let v: Int
    let quarter: Quarter
    let hymns: [HymnRow]
    let egw: [EgwRow]
    let lessons: [LessonRow]
    let bible: [BibleRow]
}

/// One lenient decoder for every bundled file (unknown keys are ignored by Codable already).
enum AppJson {
    static let decoder: JSONDecoder = JSONDecoder()
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T { try decoder.decode(type, from: data) }
}
