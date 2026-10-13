import SwiftUI

/**
 The site's `.site-nav`: brand (symbol + «Pisacoma») on the left, search and hamburger (42 pt,
 12 pt radius) on the right. 66 pt tall below the status bar.
 */
struct TopBar: View {
    @Environment(\.chrome) private var c
    let menuOpen: Bool
    let onBrand: () -> Void
    let onSearch: () -> Void
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 11) {
                    IconView(name: "sda_symbol", color: c.brandMark).frame(width: Metrics.brandMarkW, height: Metrics.brandMarkH)
                    Text("Pisacoma").font(Fonts.fraunces(17.6, weight: .bold)).foregroundStyle(c.brandStrong)
                }
                .pressable(scale: 0.98, tag: "nav-brand", action: onBrand)
                .accessibilityLabel("Pisacoma, inicio")
                Spacer(minLength: 8)
                NavButton(icon: "ic_nav_search", label: "Buscar en todo el sitio", tag: "nav-search", action: onSearch)
                Spacer().frame(width: 8)
                NavButton(icon: menuOpen ? "ic_nav_close" : "ic_nav_menu", label: menuOpen ? "Cerrar menú" : "Abrir menú", tag: "nav-menu", action: onMenu)
            }
            .padding(.horizontal, Metrics.navPaddingH)
            .frame(height: Metrics.navHeight)
            Rectangle().fill(c.navBorder).frame(height: 1)
        }
        .background(c.navBackground)
    }
}

struct NavButton: View {
    @Environment(\.chrome) private var c
    let icon: String
    let label: String
    let tag: String
    let action: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.navButtonRadius).fill(c.navButtonBg)
            RoundedRectangle(cornerRadius: Metrics.navButtonRadius).stroke(c.navButtonBorder, lineWidth: 1)
            IconView(name: icon, color: c.navButtonFg).frame(width: 20, height: 20)
        }
        .frame(width: Metrics.navButton, height: Metrics.navButton)
        .pressable(tag: tag, action: action)
        .accessibilityLabel(label)
    }
}
