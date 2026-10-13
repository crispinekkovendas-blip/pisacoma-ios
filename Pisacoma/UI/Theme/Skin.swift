import SwiftUI

/// The look a route gets: cream pastel pages, the dark base of quiz / quien / videos, and the
/// Pampa Abierta palette on the home. The site ignores the OS dark mode: one fixed look per route.
enum Skin { case pastel, dark, home }

/// Chrome colours the top bar, menu and footer read, per skin (Android `ChromeColors`).
struct ChromeColors {
    let background: Color
    let navBackground: Color
    let navBorder: Color
    let brandMark: Color
    let brandStrong: Color
    let brandSub: Color
    let navButtonBg: Color
    let navButtonBorder: Color
    let navButtonFg: Color
    let footerText: Color
    let footerBorder: Color
    let bodyText: Color
    let isLight: Bool

    static let pastel = ChromeColors(
        background: Tokens.cream,
        navBackground: Tokens.creamNav,
        navBorder: Tokens.sageA(0.12),
        brandMark: Tokens.sage,
        brandStrong: Tokens.forest,
        brandSub: Tokens.sageText,
        navButtonBg: Tokens.sageA(0.06),
        navButtonBorder: Tokens.sageA(0.20),
        navButtonFg: Tokens.forest,
        footerText: Tokens.sageText,
        footerBorder: Tokens.sageA(0.12),
        bodyText: Tokens.ink,
        isLight: true
    )

    static let dark = ChromeColors(
        background: Tokens.bg,
        navBackground: Color(hex: 0x0D1117, alpha: 0.88),
        navBorder: Tokens.border,
        brandMark: Tokens.accentLight,
        brandStrong: .white,
        brandSub: Tokens.textFaint,
        navButtonBg: Color.white.opacity(0.04),
        navButtonBorder: Color.white.opacity(0.10),
        navButtonFg: Tokens.text,
        footerText: Tokens.textFaint,
        footerBorder: Tokens.border,
        bodyText: Tokens.text,
        isLight: false
    )

    /// The home keeps the cream chrome; its own sections paint the Pampa palette.
    static let home = pastel

    static func of(_ skin: Skin) -> ChromeColors {
        switch skin {
        case .pastel: return .pastel
        case .dark: return .dark
        case .home: return .home
        }
    }
}

private struct ChromeKey: EnvironmentKey { static let defaultValue = ChromeColors.pastel }
private struct SkinKey: EnvironmentKey { static let defaultValue = Skin.pastel }

extension EnvironmentValues {
    var chrome: ChromeColors {
        get { self[ChromeKey.self] }
        set { self[ChromeKey.self] = newValue }
    }
    var skin: Skin {
        get { self[SkinKey.self] }
        set { self[SkinKey.self] = newValue }
    }
}

extension View {
    /// Applies a route's skin to the subtree (Android `PisacomaTheme`).
    func pisacomaTheme(_ skin: Skin) -> some View {
        environment(\.skin, skin)
            .environment(\.chrome, ChromeColors.of(skin))
            .preferredColorScheme(ChromeColors.of(skin).isLight ? .light : .dark)
    }
}
