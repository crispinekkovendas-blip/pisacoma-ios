import SwiftUI

/// The navigation stack over the router: every route renders inside SiteScaffold, except the
/// bare first-open chooser (no top bar or menu to escape through).
struct RootView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var app: AppModel

    var body: some View {
        NavigationStack(path: $router.path) {
            screen(for: router.root, isRoot: true)
                .navigationDestination(for: Route.self) { route in
                    screen(for: route, isRoot: false)
                }
        }
        .onOpenURL { url in
            if let r = Route.parse(url: url) {
                if router.root == .descargas { router.after = r } else { router.go(r) }
            }
        }
    }

    @ViewBuilder
    private func screen(for route: Route, isRoot: Bool) -> some View {
        if route == .descargas && isRoot {
            DescargasView(bare: true, onContinue: { router.continueFirstRun() })
                .background(Tokens.cream.ignoresSafeArea())
                .pisacomaTheme(.pastel)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            SiteScaffold(route: route) { ScreenFor(route: route) }
                .id("\(route.path)#\(router.generation)")
        }
    }
}

/// Dispatches a route to its screen.
struct ScreenFor: View {
    let route: Route

    var body: some View {
        switch route {
        case .descargas: DescargasView(bare: false, onContinue: {})
        default: PlaceholderScreen(route: route)
        }
    }
}

/// Screens are added task by task; the rest are placeholders.
struct PlaceholderScreen: View {
    @Environment(\.chrome) private var c
    let route: Route
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(route.path).font(Fonts.fraunces(20)).foregroundStyle(c.bodyText).padding(24)
            Spacer()
            SiteFooter()
        }
        .accessibilityIdentifier("screen-\(route.base)")
    }
}
