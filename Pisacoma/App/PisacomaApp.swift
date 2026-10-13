import SwiftUI

@main
struct PisacomaApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Pisacoma")
                .font(Fonts.fraunces(28, weight: .medium))
                .foregroundStyle(Tokens.forest)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.cream)
        }
    }
}
