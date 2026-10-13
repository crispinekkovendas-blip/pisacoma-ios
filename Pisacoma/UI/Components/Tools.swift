import SwiftUI
import UIKit

/// `.open-btn` / `.share-pill`: a cream pill with a 16 pt icon and Inter 500 label.
struct ToolPill: View {
    let icon: String
    let label: String
    var tag: String = ""
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            IconView(name: icon, color: Tokens.forest).frame(width: 16, height: 16)
            Text(label).font(Fonts.inter(14.4, weight: .medium)).foregroundStyle(Tokens.forest)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color(hex: 0xFBF9EF, alpha: 0.8)))
        .overlay(Capsule().stroke(Color(hex: 0x2C4128, alpha: 0.28), lineWidth: 1))
        .pressable(scale: 0.97, tag: tag, action: action)
    }
}

/// «Compartir» (site components/share-button.tsx): the share sheet with the message and the site link.
struct ShareButton: View {
    let title: String
    let text: String
    let path: String
    var label: String = "Compartir"

    var body: some View {
        ToolPill(icon: "ic_share", label: label, tag: "share") {
            let url = AudioUrls.site + path
            let vc = UIActivityViewController(activityItems: ["\(text)\n\(url)"], applicationActivities: nil)
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.rootViewController?.topMost.present(vc, animated: true)
        }
    }
}

extension UIViewController {
    var topMost: UIViewController { presentedViewController?.topMost ?? self }
}

/**
 The readers' text-size steps (site: a signal from 0.92 to 1.42 rem in 0.08 steps, default 1.05).
 Pure arithmetic kept here so the three readers (lección, biblia, EGW) agree.
 */
enum TextScale {
    static let `default`: CGFloat = 1.05
    static let min: CGFloat = 0.92
    static let max: CGFloat = 1.42
    static let step: CGFloat = 0.08
    static func smaller(_ s: CGFloat) -> CGFloat { Swift.max(min, s - step) }
    static func larger(_ s: CGFloat) -> CGFloat { Swift.min(max, s + step) }
}

/// A 32 pt toolbar button (`.tb-icon`): sage outline, pressed/active fill.
struct ToolbarIcon<Content: View>: View {
    var icon: String? = nil
    let label: String
    var active: Bool = false
    var tag: String = ""
    let action: () -> Void
    @ViewBuilder var content: () -> Content

    init(icon: String? = nil, label: String, active: Bool = false, tag: String = "", action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon; self.label = label; self.active = active; self.tag = tag; self.action = action; self.content = content
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(active ? Tokens.forest : Tokens.sageA(0.06))
            RoundedRectangle(cornerRadius: 10).stroke(active ? Tokens.forest : Tokens.sageA(0.20), lineWidth: 1)
            if let icon { IconView(name: icon, color: active ? Tokens.cream : Tokens.forest).frame(width: 15, height: 15) } else { content() }
        }
        .frame(width: 32, height: 32)
        .pressable(tag: tag, action: action)
        .accessibilityLabel(label)
    }
}

extension ToolbarIcon where Content == EmptyView {
    init(icon: String, label: String, active: Bool = false, tag: String = "", action: @escaping () -> Void) {
        self.init(icon: icon, label: label, active: active, tag: tag, action: action) { EmptyView() }
    }
}

/// The «A» / «A» pair (`.tb-letter sm` / `lg`).
struct TextSizeControls: View {
    let onSmaller: () -> Void
    let onLarger: () -> Void
    var body: some View {
        ToolbarIcon(label: "Texto más pequeño", tag: "text-smaller", action: onSmaller) {
            Text("A").font(Fonts.fraunces(12, weight: .semibold)).foregroundStyle(Tokens.forest)
        }
        ToolbarIcon(label: "Texto más grande", tag: "text-larger", action: onLarger) {
            Text("A").font(Fonts.fraunces(17, weight: .semibold)).foregroundStyle(Tokens.forest)
        }
    }
}
