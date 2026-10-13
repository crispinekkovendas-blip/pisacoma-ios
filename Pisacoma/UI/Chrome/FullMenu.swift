import SwiftUI

/**
 The site's mobile menu (`.mm`): a scrim and a cream panel sliding in from the right with the
 eleven destinations, numbered, with their icon tile and description, and the circle symbol in
 the foot. Always cream, whatever the route's skin (as on the site).
 */
struct FullMenu: View {
    let open: Bool
    let current: Route?
    let onNavigate: (Route) -> Void
    let onClose: () -> Void
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack(alignment: .trailing) {
            if open {
                Color(hex: 0x0D1117, alpha: 0.5)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .accessibilityLabel("Cerrar menú")
                    .transition(.opacity)
            }
            if open {
                GeometryReader { geo in
                    let panelW = min(440, geo.size.width * 0.92)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        panel.frame(width: panelW)
                    }
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: open)
    }

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Spacer(); closeButton }
                Spacer().frame(height: 12)
                Eyebrow("— Navegación · \(navItems.count) destinos", Tokens.sage, size: 10.5, tracking: 2.4, weight: .bold)
                Spacer().frame(height: 14)
                (Text("¿A dónde ").font(Fonts.fraunces(27.2, weight: .medium)) + Text("vamos").font(Fonts.fraunces(27.2, weight: .regular, italic: true)).foregroundColor(Tokens.sage) + Text("?").font(Fonts.fraunces(27.2, weight: .medium)))
                    .tracking(-0.025 * 27.2)
                    .foregroundStyle(Tokens.inkDeep)
                Spacer().frame(height: 22)
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                VStack(spacing: 4) {
                    ForEach(Array(navItems.enumerated()), id: \.offset) { i, item in
                        let active: Bool = {
                            guard let current else { return false }
                            if case .home = item.route { return current == .home }
                            return current.base.hasPrefix(item.route.base)
                        }()
                        MenuRow(index: i + 1, item: item, desc: item.route == .escuela ? quarterLabel(now) : item.desc, active: active) { onNavigate(item.route) }
                    }
                }
                Spacer().frame(height: 22)
                Rectangle().fill(Tokens.sageA(0.18)).frame(height: 1)
                Spacer().frame(height: 14)
                descargasRow
                Spacer().frame(height: 14)
                HStack(spacing: 14) {
                    IconView(name: "sda_symbol_circle", color: Tokens.sage).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pisacoma · 3.940 m").font(Fonts.fraunces(14, weight: .semibold)).foregroundStyle(Tokens.forest)
                        Eyebrow("Chucuito · Puno · MLT", Tokens.sageText)
                    }
                }
            }
            .padding(.horizontal, Metrics.menuPaddingH)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(LinearGradient(colors: [Tokens.menuTop, Tokens.menuBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .accessibilityIdentifier("menu-panel")
    }

    private var closeButton: some View {
        ZStack {
            Circle().fill(Tokens.sageA(0.08))
            Circle().stroke(Tokens.sageA(0.20), lineWidth: 1)
            IconView(name: "ic_nav_close", color: Tokens.forest).frame(width: 18, height: 18)
        }
        .frame(width: 40, height: 40)
        .pressable(tag: "menu-close", action: onClose)
        .accessibilityLabel("Cerrar menú")
    }

    private var descargasRow: some View {
        let stored = app.content.storedBytes()
        let mode = app.contentMode
        let parts = [mode?.label, stored > 0 ? "Guardado: \(formatMb(stored))" : nil].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 3) {
            Text("Descargas").font(Fonts.fraunces(15, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
            Eyebrow(parts.isEmpty ? "Qué guardar en este teléfono" : parts.joined(separator: " · "), Tokens.sageText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .pressable(scale: 0.985, tag: "menu-descargas") { onNavigate(.descargas) }
    }
}

private struct MenuRow: View {
    let index: Int
    let item: NavItem
    let desc: String
    let active: Bool
    let onClick: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(Fonts.fraunces(15.2, weight: .bold, italic: true))
                .foregroundStyle(active ? Tokens.forest : Tokens.sageSoft)
                .frame(width: 22, alignment: .leading)
            ZStack {
                RoundedRectangle(cornerRadius: Metrics.menuIconRadius).fill(active ? Tokens.forest : Tokens.leafA(0.10))
                RoundedRectangle(cornerRadius: Metrics.menuIconRadius).stroke(active ? Tokens.forest : Tokens.sageA(0.18), lineWidth: 1)
                IconView(name: item.icon, color: active ? Tokens.cream : Tokens.sage).frame(width: 20, height: 20)
            }
            .frame(width: Metrics.menuIcon, height: Metrics.menuIcon)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label)
                    .font(Fonts.fraunces(18.9, weight: active ? .regular : .medium, italic: active))
                    .tracking(-0.022 * 18.9)
                    .foregroundStyle(active ? Tokens.forest : Tokens.ink)
                if !desc.isEmpty { Eyebrow(desc, Tokens.sageText, size: 10) }
            }
            Spacer(minLength: 0)
            if active { IconView(name: "ic_nav_arrow", color: Tokens.sage).frame(width: 20, height: 20) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Metrics.menuRowRadius)
                .fill(active ? AnyShapeStyle(LinearGradient(colors: [Tokens.sageA(0.16), Tokens.sageA(0.02)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.clear))
        )
        .pressable(scale: 0.985, tag: "menu-\(item.label)", action: onClick)
    }
}
