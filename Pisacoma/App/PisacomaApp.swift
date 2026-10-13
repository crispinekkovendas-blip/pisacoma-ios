import SwiftUI

@main
struct PisacomaApp: App {
    @StateObject private var app = AppModel.shared
    @StateObject private var router: Router

    init() {
        let a = AppModel.shared
        // Until the phone has chosen what to keep, the only screen is /descargas.
        let firstRun = a.contentMode == nil
        _router = StateObject(wrappedValue: Router(root: firstRun ? .descargas : .home))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(router)
        }
    }
}
