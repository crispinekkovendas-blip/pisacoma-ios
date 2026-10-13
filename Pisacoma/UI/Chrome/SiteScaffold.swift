import SwiftUI

/**
 The site's layout around every route: top bar, the route's content, the menu overlay and the
 missing-content notice. Screens that scroll put the footer inside their own list (SiteFooter).
 */
struct SiteScaffold<Content: View>: View {
    let route: Route
    @ViewBuilder let content: () -> Content
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var app: AppModel
    @State private var menuOpen = false

    var body: some View {
        let c = ChromeColors.of(route.skin)
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TopBar(
                    menuOpen: menuOpen,
                    onBrand: { menuOpen = false; router.go(.home) },
                    onSearch: { menuOpen = false; router.go(.buscar) },
                    onMenu: { menuOpen.toggle() }
                )
                content().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if app.content.missing != nil && route != .descargas {
                MissingContentNotice(
                    onRetry: { app.content.missing = nil; router.reload() },
                    onDownloads: { app.content.missing = nil; menuOpen = false; router.go(.descargas) }
                )
                .padding(16)
            }
            FullMenu(open: menuOpen, current: route, onNavigate: { menuOpen = false; router.go($0) }, onClose: { menuOpen = false })
                .ignoresSafeArea(edges: .bottom)
        }
        .background(c.background.ignoresSafeArea())
        .pisacomaTheme(route.skin)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// `.site-foot`: one centred 12pt line over a hairline, with the bottom inset.
struct SiteFooter: View {
    @Environment(\.chrome) private var c
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(c.footerBorder).frame(height: 1)
            Text("Iglesia Adventista del Séptimo Día · Pisacoma, Chucuito, Puno, Perú · Misión Peruana del Lago Titicaca")
                .font(Fonts.inter(12))
                .lineSpacing(4)
                .foregroundStyle(c.footerText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 48)
        }
        .accessibilityIdentifier("site-footer")
    }
}
