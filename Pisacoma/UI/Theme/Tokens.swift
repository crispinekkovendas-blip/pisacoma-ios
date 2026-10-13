import SwiftUI

extension Color {
    /// `Color(hex: 0xF5F3E6)` or with alpha `Color(hex: 0xF5F3E6, alpha: 0.5)`.
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// The site's CSS values under their names (quiz-qwik global.css, pastel.css, the Pampa palette);
/// same names as the Android `Tokens.kt`.
enum Tokens {
    // ---- dark base (quiz / quien / videos) ----
    static let bg = Color(hex: 0x0D1117)            // --bg
    static let bg2 = Color(hex: 0x161B22)           // --bg-2
    static let border = Color(hex: 0x21262D)        // --border
    static let primary = Color(hex: 0x1E3A5F)       // --primary
    static let primaryLight = Color(hex: 0x2D5A8E)  // --primary-light
    static let accent = Color(hex: 0xC9963B)        // --accent
    static let accentLight = Color(hex: 0xE8B85A)   // --accent-light
    static let text = Color.white.opacity(0.92)     // --text
    static let textMuted = Color.white.opacity(0.55) // --text-muted
    static let textFaint = Color.white.opacity(0.5) // --text-faint
    static let green = Color(hex: 0x3BD68A)         // --green
    static let red = Color(hex: 0xE65B5B)           // --red

    // ---- cream pastel pages ----
    static let cream = Color(hex: 0xF5F3E6)         // body background
    static let creamNav = Color(hex: 0xF7F4E6, alpha: 0.86) // .site-nav
    static let ink = Color(hex: 0x1F2B1C)           // body color
    static let forest = Color(hex: 0x2C4128)        // brand strong, headings
    static let sage = Color(hex: 0x4A6741)          // brand mark, accents
    static let sageText = Color(hex: 0x627253)      // brand span, footer text
    static let sageSoft = Color(hex: 0x6F8E57)      // .mm-num
    static let inkDeep = Color(hex: 0x16241A)       // .mm-title
    static let sageLeaf = Color(hex: 0x7A9D52)      // radial glow / icon tiles
    static let ochrePastel = Color(hex: 0xB8904F)   // radial glow
    static let menuTop = Color(hex: 0xF7F4EA)       // .mm-panel gradient start
    static let menuBottom = Color(hex: 0xECE9D6)    // .mm-panel gradient end
    static let ledeInk = Color(hex: 0x4D6044)       // .lede

    // ---- Pampa Abierta (home) ----
    static let basalt = Color(hex: 0x2A2620)
    static let parchment = Color(hex: 0xF0E8D0)
    static let olive = Color(hex: 0x5D6B3F)
    static let ichu = Color(hex: 0x7D8A5A)
    static let olivePale = Color(hex: 0xD4D6B0)
    static let ochre = Color(hex: 0xC08428)
    static let ochreLight = Color(hex: 0xD9B070)
    static let ochreDeep = Color(hex: 0x8A5418)
    static let titicaca = Color(hex: 0x1C5D8E)

    /// sage with alpha (`rgba(74,103,65,a)`).
    static func sageA(_ a: Double) -> Color { Color(hex: 0x4A6741, alpha: a) }
    /// leaf green with alpha (`rgba(122,157,82,a)`).
    static func leafA(_ a: Double) -> Color { Color(hex: 0x7A9D52, alpha: a) }
    /// ochre with alpha (`rgba(184,144,79,a)`).
    static func ochreA(_ a: Double) -> Color { Color(hex: 0xB8904F, alpha: a) }
}

/// The ochre used for numerals all over the cream pages and its darker label tone.
enum Ochre {
    static let numeral = Color(hex: 0xA78447)
    static let label = Color(hex: 0x846939)
    static let rule = Color(hex: 0xB8924F)
}

/// Layout numbers from the site's CSS (phone breakpoints), as on Android `Metrics`.
enum Metrics {
    static let navHeight: CGFloat = 66
    static let navPaddingH: CGFloat = 20
    static let brandMarkW: CGFloat = 40
    static let brandMarkH: CGFloat = 36
    static let navButton: CGFloat = 42
    static let navButtonRadius: CGFloat = 12
    static let menuPaddingH: CGFloat = 22
    static let menuPaddingTop: CGFloat = 76
    static let menuIcon: CGFloat = 40
    static let menuIconRadius: CGFloat = 13
    static let menuRowRadius: CGFloat = 14
}
