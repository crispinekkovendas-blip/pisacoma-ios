import XCTest
@testable import Pisacoma

final class ContentStoreTests: XCTestCase {
    private var tmp: URL!
    private var remote: [String: String] = ["data/x.json": "{\"x\":1}", "data/big.json": "0123456789"]
    private var offline = false
    private var fetched = 0
    private let manifest = Manifest(files: [ContentFile(path: "data/x.json", bytes: 7, pack: "biblia"), ContentFile(path: "data/big.json", bytes: 10, pack: "egw")])
    private var mode: ContentMode? = .uso

    override func setUp() {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cs-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        offline = false; fetched = 0; mode = .uso
    }

    override func tearDown() { try? FileManager.default.removeItem(at: tmp) }

    private func store() -> ContentStore {
        let bundledDir = tmp.appendingPathComponent("bundled")
        try? FileManager.default.createDirectory(at: bundledDir.appendingPathComponent("data"), withIntermediateDirectories: true)
        try? "{\"b\":1}".write(to: bundledDir.appendingPathComponent("data/bundled.json"), atomically: true, encoding: .utf8)
        return ContentStore(bundled: FileAssetSource(root: bundledDir), dir: tmp.appendingPathComponent("store"), manifest: manifest, mode: { [weak self] in self?.mode }) { [self] path in
            fetched += 1
            if offline { throw Http.Offline() }
            guard let s = remote[path] else { throw Http.Status(code: 404) }
            return Data(s.utf8)
        }
    }

    func testReadsBundledFirst() async throws {
        XCTAssertEqual(try await store().readText("data/bundled.json"), "{\"b\":1}")
        XCTAssertEqual(fetched, 0)
    }

    func testFetchesAndStoresOnUse() async throws {
        let s = store()
        XCTAssertEqual(try await s.readText("data/x.json"), "{\"x\":1}")
        XCTAssertTrue(s.isStored("data/x.json"))
        XCTAssertEqual(try await s.readText("data/x.json"), "{\"x\":1}")
        XCTAssertEqual(fetched, 1)
    }

    func testOnlineModeNeverWrites() async throws {
        mode = .enLinea
        let s = store()
        _ = try await s.read("data/x.json")
        XCTAssertFalse(s.isStored("data/x.json"))
        XCTAssertEqual(s.storedBytes(), 0)
    }

    func testOfflineMissingThrowsAndReports() async throws {
        offline = true
        let s = store()
        do { _ = try await s.read("data/x.json"); XCTFail("expected ContentMissing") } catch let e as ContentMissing { XCTAssertEqual(e.path, "data/x.json") }
        let exp = expectation(description: "missing published on main")
        DispatchQueue.main.async { XCTAssertEqual(s.missing, "data/x.json"); exp.fulfill() }
        await fulfillment(of: [exp], timeout: 2)
    }

    func testBackgroundDownloadFailureDoesNotRaiseTheNotice() async throws {
        offline = true
        let s = store()
        do { try await s.download("data/x.json"); XCTFail("expected error") } catch {}
        let exp = expectation(description: "no notice")
        DispatchQueue.main.async { XCTAssertNil(s.missing); exp.fulfill() }
        await fulfillment(of: [exp], timeout: 2)
    }

    func testStaleFileIsRefetched() async throws {
        let s = store()
        let f = s.file("data/x.json")
        try FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "old".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertFalse(s.isStored("data/x.json"))
        XCTAssertEqual(try await s.readText("data/x.json"), "{\"x\":1}")
        XCTAssertEqual(fetched, 1)
        XCTAssertTrue(s.isStored("data/x.json"))
    }

    func testOfflineStoredStillReads() async throws {
        let s = store()
        _ = try await s.read("data/x.json")
        offline = true
        XCTAssertEqual(try await s.readText("data/x.json"), "{\"x\":1}")
    }

    func testExistsUsesManifestNotNetwork() async throws {
        offline = true
        let s = store()
        let a = await s.exists("data/x.json"); XCTAssertTrue(a)
        let b = await s.exists("data/bundled.json"); XCTAssertTrue(b)
        let c = await s.exists("data/nope.json"); XCTAssertFalse(c)
        XCTAssertEqual(fetched, 0)
    }

    func testRejectsShortBody() async throws {
        remote["data/big.json"] = "0123"
        let s = store()
        do { _ = try await s.read("data/big.json"); XCTFail("expected ShortBody") } catch let e as ShortBody { XCTAssertEqual(e.got, 4) }
        XCTAssertFalse(s.isStored("data/big.json"))
    }

    func testDownloadIsIdempotent() async throws {
        let s = store()
        try await s.download("data/x.json")
        try await s.download("data/x.json")
        XCTAssertEqual(fetched, 1)
        XCTAssertEqual(s.storedBytes(), 7)
        XCTAssertEqual(s.storedCount(), 1)
    }

    func testClearEmptiesTheStore() async throws {
        let s = store()
        try await s.download("data/x.json")
        s.clear()
        XCTAssertEqual(s.storedCount(), 0)
        XCTAssertFalse(s.isStored("data/x.json"))
    }

    func testNilModeBehavesLikeUso() async throws {
        mode = nil
        let s = store()
        _ = try await s.read("data/x.json")
        XCTAssertTrue(s.isStored("data/x.json"))
    }
}
