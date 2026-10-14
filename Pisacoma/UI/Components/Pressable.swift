import SwiftUI

/// The site's `:active { transform: scale(.96) }` — every tappable thing shrinks a little while pressed.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension View {
    /// A test identifier on a container that keeps its children reachable by XCUITest
    /// (a bare `accessibilityIdentifier` on a VStack hides the buttons inside it).
    func uiId(_ id: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }

    /// Wraps the view in a Button with the pressable style (Android `Modifier.pressable`).
    func pressable(scale: CGFloat = 0.96, enabled: Bool = true, tag: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) { self }
            .buttonStyle(PressableStyle(scale: scale))
            .disabled(!enabled)
            .accessibilityIdentifier(tag ?? "")
    }
}
