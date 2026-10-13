import XCTest
@testable import Pisacoma

final class SmokeTests: XCTestCase {
    func testTokensAreTheSitesValues() {
        // cream #f5f3e6 → red channel 0xF5 / 255
        let cream = UIColor(Tokens.cream)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        cream.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int((r * 255).rounded()), 0xF5)
        XCTAssertEqual(Int((g * 255).rounded()), 0xF3)
        XCTAssertEqual(Int((b * 255).rounded()), 0xE6)
    }

    func testCssWeights() {
        XCTAssertEqual(Fonts.cssWeight(.regular), 400)
        XCTAssertEqual(Fonts.cssWeight(.semibold), 600)
        XCTAssertEqual(Fonts.cssWeight(.bold), 700)
    }
}
