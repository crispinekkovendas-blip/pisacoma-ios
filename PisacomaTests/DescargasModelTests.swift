import XCTest
@testable import Pisacoma

@MainActor
final class DescargasModelTests: XCTestCase {
    private var tmp: URL!
    private let manifest = Manifest(files: [
        ContentFile(path: "data/himnario-es.json", bytes: 1_100_000, pack: "himnario-es"),
        ContentFile(path: "data/biblia/1.json", bytes: 4_000_000, pack: "biblia"),
        ContentFile(path: "data/egw/cc.json", bytes: 20_000_000, pack: "egw"),
    ])
    private var offline = false
    private var userState: UserState!
    private var store: ContentStore!
    private var downloader: ContentDownloader!

    override func setUp() {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("dm-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp.appendingPathComponent("b"), withIntermediateDirectories: true)
        offline = false
        userState = UserState(MemoryStore())
        let us = userState!
        let m = manifest
        store = ContentStore(bundled: FileAssetSource(root: tmp.appendingPathComponent("b")), dir: tmp.appendingPathComponent("s"), manifest: manifest, mode: { ContentMode.of(us.string(UserState.Keys.contentMode)) }) { [self] p in
            if offline { throw Http.Offline() }
            return Data(count: Int(m.byPath(p)!.bytes))
        }
        downloader = ContentDownloader(store: store) { ok in us.set(UserState.Keys.contentPending, !ok) }
    }

    override func tearDown() { try? FileManager.default.removeItem(at: tmp) }

    private func model() -> DescargasModel { DescargasModel(store: store, downloader: downloader, userState: userState) }

    private func awaitDownload() async {
        for _ in 0..<200 {
            if case .running = downloader.state { try? await Task.sleep(nanoseconds: 50_000_000); continue }
            if downloader.state == .idle { try? await Task.sleep(nanoseconds: 50_000_000); continue }
            return
        }
    }

    func testFirstRunHasNoCurrentAndCannotContinue() {
        let s = model().state
        XCTAssertNil(s.current)
        XCTAssertFalse(s.canContinue)
        XCTAssertEqual(s.storedText, "")
    }

    func testOptionSizesComeFromTheManifest() {
        let o = model().state.options
        XCTAssertEqual(o.map(\.mode), [.todo, .esencial, .uso, .enLinea])
        XCTAssertEqual(o[0].size, "25 MB")
        XCTAssertEqual(o[1].size, "5,1 MB")
        XCTAssertEqual(o[2].size, "")
        XCTAssertEqual(o[3].size, "")
    }

    func testChooseUsoStoresTheModeWithoutDownloading() {
        let m = model()
        m.choose(.uso)
        XCTAssertEqual(userState.string(UserState.Keys.contentMode), "uso")
        XCTAssertFalse(userState.bool(UserState.Keys.contentPending))
        XCTAssertTrue(m.state.canContinue)
        XCTAssertEqual(store.storedCount(), 0)
    }

    func testChooseEsencialDownloadsAndClearsPending() async {
        let m = model()
        m.choose(.esencial)
        XCTAssertEqual(userState.string(UserState.Keys.contentMode), "esencial")
        await awaitDownload()
        XCTAssertEqual(downloader.state, .done(totalBytes: 5_100_000))
        XCTAssertFalse(userState.bool(UserState.Keys.contentPending))
        XCTAssertEqual(store.storedCount(), 2)
        XCTAssertFalse(store.isStored("data/egw/cc.json"))
        m.refresh()
        XCTAssertEqual(m.state.storedText, "Guardado en este teléfono · 5,1 MB")
        XCTAssertEqual(m.state.missingCount, 0)
    }

    func testOfflineChoiceStaysPendingWithAnError() async {
        offline = true
        let m = model()
        m.choose(.todo)
        await awaitDownload()
        if case .error = downloader.state {} else { XCTFail("expected error, got \(downloader.state)") }
        XCTAssertTrue(userState.bool(UserState.Keys.contentPending))
        m.refresh()
        XCTAssertEqual(m.state.missingCount, 3)
    }

    func testClearEmptiesTheStoreAndKeepsTheMode() async {
        let m = model()
        m.choose(.esencial)
        await awaitDownload()
        m.clear()
        XCTAssertEqual(store.storedCount(), 0)
        XCTAssertEqual(userState.string(UserState.Keys.contentMode), "esencial")
        XCTAssertTrue(userState.bool(UserState.Keys.contentPending))
        XCTAssertEqual(m.state.missingCount, 2)
    }
}
