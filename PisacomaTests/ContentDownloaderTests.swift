import XCTest
@testable import Pisacoma

final class ContentDownloaderTests: XCTestCase {
    private var tmp: URL!
    private let manifest = Manifest(files: [
        ContentFile(path: "data/himnario-es.json", bytes: 3, pack: "himnario-es"),
        ContentFile(path: "data/biblia/1.json", bytes: 4, pack: "biblia"),
        ContentFile(path: "data/egw/cc.json", bytes: 5, pack: "egw"),
    ])
    private let remote = ["data/himnario-es.json": "abc", "data/biblia/1.json": "defg", "data/egw/cc.json": "hijkl"]
    private var failing: Set<String> = []
    private var fetched: [String] = []
    private let lock = NSLock()

    override func setUp() {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cd-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp.appendingPathComponent("b"), withIntermediateDirectories: true)
        failing = []; fetched = []
    }

    override func tearDown() { try? FileManager.default.removeItem(at: tmp) }

    private func store() -> ContentStore {
        ContentStore(bundled: FileAssetSource(root: tmp.appendingPathComponent("b")), dir: tmp.appendingPathComponent("s"), manifest: manifest, mode: { .todo }) { [self] p in
            lock.lock(); fetched.append(p); lock.unlock()
            if failing.contains(p) { throw Http.Offline() }
            return Data(remote[p]!.utf8)
        }
    }

    func testDownloadsEverythingForTodo() async {
        let s = store()
        var completed: Bool?
        let d = ContentDownloader(store: s) { completed = $0 }
        await d.start(.todo)?.value
        XCTAssertEqual(d.state, .done(totalBytes: 12))
        XCTAssertEqual(s.storedCount(), 3)
        XCTAssertEqual(completed, true)
    }

    func testEsencialSkipsEgw() async {
        let s = store()
        let d = ContentDownloader(store: s)
        await d.start(.esencial)?.value
        XCTAssertFalse(s.isStored("data/egw/cc.json"))
        XCTAssertEqual(d.state, .done(totalBytes: 7))
    }

    func testSkipsStoredFiles() async throws {
        let s = store()
        try await s.download("data/biblia/1.json")
        fetched = []
        await ContentDownloader(store: s).start(.todo)?.value
        XCTAssertFalse(fetched.contains("data/biblia/1.json"))
    }

    func testCountsFailuresAndRetries() async {
        failing = ["data/egw/cc.json"]
        let s = store()
        var completed: Bool?
        let d = ContentDownloader(store: s) { completed = $0 }
        await d.start(.todo)?.value
        XCTAssertEqual(d.state, .error(failed: 1, totalFiles: 3))
        XCTAssertEqual(fetched.filter { $0 == "data/egw/cc.json" }.count, 3)
        XCTAssertEqual(completed, false)
    }

    func testNothingToDoReturnsNilAndDone() async {
        let d = ContentDownloader(store: store())
        XCTAssertNil(d.start(.uso))
        XCTAssertEqual(d.state, .done(totalBytes: 0))
    }

    func testMissingForListsOnlyAbsentFiles() async throws {
        let s = store()
        try await s.download("data/himnario-es.json")
        XCTAssertEqual(ContentDownloader(store: s).missingFor(.esencial).map(\.path), ["data/biblia/1.json"])
    }

    func testSecondStartWhileRunningIsIgnored() async {
        let s = store()
        let d = ContentDownloader(store: s)
        let t = d.start(.todo)
        XCTAssertNil(d.start(.todo))
        await t?.value
        XCTAssertEqual(fetched.count, 3)
    }
}
