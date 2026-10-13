import Foundation

/// A string key/value store: UserDefaults on a phone, a dictionary in tests.
protocol KeyValueStore: AnyObject {
    func get(_ key: String) -> String?
    func put(_ key: String, _ value: String?)
    func all() -> [String: String]
    /// Called with the key after every put. Returns a token; drop it to stop listening.
    func addListener(_ listener: @escaping (String) -> Void) -> AnyObject
}

final class ListenerToken {
    let id = UUID()
}

/// UserDefaults suite `pisacoma`, with the listeners kept here (UserDefaults has no per-key observation).
final class DefaultsStore: KeyValueStore {
    private let defaults: UserDefaults
    private var listeners: [UUID: (String) -> Void] = [:]
    private let lock = NSLock()

    init(_ defaults: UserDefaults = UserDefaults(suiteName: UserState.suiteName) ?? .standard) { self.defaults = defaults }

    func get(_ key: String) -> String? { defaults.string(forKey: key) }

    func put(_ key: String, _ value: String?) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        notify(key)
    }

    func all() -> [String: String] {
        defaults.dictionaryRepresentation().compactMapValues { $0 as? String }
    }

    func addListener(_ listener: @escaping (String) -> Void) -> AnyObject {
        let token = ListenerToken()
        lock.lock(); listeners[token.id] = listener; lock.unlock()
        return TokenHolder(token: token) { [weak self] in self?.remove(token.id) }
    }

    private func remove(_ id: UUID) { lock.lock(); listeners[id] = nil; lock.unlock() }

    private func notify(_ key: String) {
        lock.lock(); let ls = Array(listeners.values); lock.unlock()
        ls.forEach { $0(key) }
    }
}

/// Runs a closure when deallocated (listener removal).
final class TokenHolder {
    let token: ListenerToken
    private let onDeinit: () -> Void
    init(token: ListenerToken, onDeinit: @escaping () -> Void) { self.token = token; self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

/// In-memory store for tests.
final class MemoryStore: KeyValueStore {
    private var map: [String: String] = [:]
    private var listeners: [UUID: (String) -> Void] = [:]

    func get(_ key: String) -> String? { map[key] }
    func put(_ key: String, _ value: String?) {
        if let value { map[key] = value } else { map[key] = nil }
        listeners.values.forEach { $0(key) }
    }
    func all() -> [String: String] { map }
    func addListener(_ listener: @escaping (String) -> Void) -> AnyObject {
        let token = ListenerToken()
        listeners[token.id] = listener
        return TokenHolder(token: token) { [weak self] in self?.listeners[token.id] = nil }
    }
}

/**
 Everything the reader saves — notes, done marks, bookmarks, recents, quiz progress — under the
 site's localStorage key names, so the three surfaces store the same thing the same way.
 Booleans are "1"/"0" and lists are JSON arrays, as the site writes them.
 */
final class UserState {
    static let suiteName = "pisacoma"
    private let store: KeyValueStore

    init(_ store: KeyValueStore = DefaultsStore()) { self.store = store }

    func string(_ key: String) -> String? { store.get(key) }
    func set(_ key: String, _ value: String?) { store.put(key, value) }

    func bool(_ key: String) -> Bool { let v = store.get(key); return v == "1" || v == "true" }
    func set(_ key: String, _ value: Bool) { store.put(key, value ? "1" : "0") }

    func stringList(_ key: String) -> [String] {
        guard let raw = store.get(key), let data = raw.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return [] }
        return arr.map { v in (v as? String) ?? "\(v)" }
    }

    func set(_ key: String, _ value: [String]) {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.withoutEscapingSlashes])) ?? Data("[]".utf8)
        store.put(key, String(data: data, encoding: .utf8) ?? "[]")
    }

    /// Keys currently stored that start with `prefix` (e.g. every `egw:cc:ch` key).
    func keysWithPrefix(_ prefix: String) -> [String] { store.all().keys.filter { $0.hasPrefix(prefix) } }

    /// Every change to any key (the value is the key). Keep the token alive while listening.
    func onChange(_ handler: @escaping (String) -> Void) -> AnyObject { store.addListener(handler) }

    enum Keys {
        static func bibleNotes(_ book: Int, _ chapter: Int) -> String { "biblia:bk\(book):ch\(chapter):notes" }
        static let bibleBookmarks = "biblia:bookmarks"
        static let bibleRecent = "biblia:recent"
        static let bibleHasNotesIndex = "biblia:hasNotesIndex"
        static func egwNotes(_ slug: String, _ chapter: Int) -> String { "egw:\(slug):ch\(chapter):notes" }
        static func egwDone(_ slug: String, _ chapter: Int) -> String { "egw:\(slug):ch\(chapter):done" }
        static func egwLast(_ slug: String) -> String { "egw:\(slug):last" }
        static let egwBookmarks = "egw:bookmarks"
        static func lessonDone(_ qid: String, _ lesson: Int, _ day: Int) -> String { "escuela:\(qid):lecc\(lesson):day\(day):done" }
        static func lessonNotes(_ qid: String, _ lesson: Int, _ day: Int) -> String { "escuela:\(qid):lecc\(lesson):day\(day):notes" }
        static func lessonLastDay(_ qid: String, _ lesson: Int) -> String { "escuela:\(qid):lecc\(lesson):lastDay" }
        static func lessonBookmarks(_ qid: String) -> String { "escuela:\(qid):bookmarks" }
        static func quiz(_ slug: String) -> String { "quiz.\(slug).v1" }
        static let hymnRecent = "himnario.recent"
        static let homePaused = "inicio.videos.pausa"
        static let videosCache = "videos:cache"
        static let videosCacheAt = "videos:cacheAt"
        static let quienNames = "quien:names"
        /// «todo» | «esencial» | «uso» | «en-linea»; unset until the first open's choice.
        static let contentMode = "contenido.modo"
        /// "1" while the chosen packs are not fully stored (the download resumes on the next open).
        static let contentPending = "contenido.pendiente"
    }
}
