import XCTest
@testable import Pisacoma

/// What tools/sync-content.mjs copies into the app bundle (and the test bundle) is there.
final class ContentPresentTests: XCTestCase {
    // The unit tests are hosted by the app, so Bundle.main is the app bundle.
    private var app: URL { Bundle.main.resourceURL!.appendingPathComponent("Content") }
    private var tests: URL { Bundle(for: ContentPresentTests.self).resourceURL!.appendingPathComponent("TestContent") }

    private func assertAtLeast(_ url: URL, _ bytes: Int, file: StaticString = #filePath, line: UInt = #line) {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
        XCTAssertTrue(size >= bytes, "\(url.lastPathComponent) is \(size) bytes (need \(bytes)) — run tools/sync-content.mjs", file: file, line: line)
    }

    func testManifestIsBundled() { assertAtLeast(app.appendingPathComponent("manifest.json"), 1_000) }
    func testHomeLottieAndPoster() {
        assertAtLeast(app.appendingPathComponent("home/lottie/inicio-portrait.json"), 2_000)
        assertAtLeast(app.appendingPathComponent("home/inicio-portrait.jpg"), 20_000)
    }
    func testCoversAreBundled() {
        let covers = (try? FileManager.default.contentsOfDirectory(atPath: app.appendingPathComponent("covers").path)) ?? []
        XCTAssertEqual(covers.count, 25)
    }
    func testIndicesAreBundled() {
        for f in ["church", "bible-books", "egw-index", "featured-hymns", "home-photos", "anuncios", "videos-channels"] {
            assertAtLeast(app.appendingPathComponent("data/\(f).json"), 20)
        }
    }
    func testDownloadableContentIsInTheTestBundle() {
        assertAtLeast(tests.appendingPathComponent("data/himnario-es.json"), 500_000)
        assertAtLeast(tests.appendingPathComponent("data/biblia/1.json"), 100_000)
        assertAtLeast(tests.appendingPathComponent("data/egw/cc.json"), 100_000)
        assertAtLeast(tests.appendingPathComponent("data/escuela-sabatica.json"), 300_000)
        assertAtLeast(tests.appendingPathComponent("data/search-index.json"), 100_000)
        assertAtLeast(tests.appendingPathComponent("data/quizzes.json"), 10_000)
    }
    func testFontsLoad() {
        for f in ["fraunces", "fraunces_italic", "inter", "dm_sans", "playfair"] {
            XCTAssertTrue(Fonts.available(f), "font \(f) did not load")
        }
    }
}
