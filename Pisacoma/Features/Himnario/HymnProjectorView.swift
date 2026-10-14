import SwiftUI

private let gold = Color(hex: 0xD9B36C)
private let cream = Tokens.cream

/**
 «Proyectar» (site components/hymn-projector.tsx): a full-screen dark view of the hymn for a
 TV or a projector. Screen 0 is the cover; then one per stanza with the chorus repeated.
 Tap the left third to go back, anywhere else to advance. Keeps the screen on.
 */
struct HymnProjectorView: View {
    let number: Int
    let title: String
    let bibleRef: String?
    let slides: [ProjectorSlide]
    let onClose: () -> Void
    @State private var idx = 0

    var body: some View {
        let total = slides.count + 1
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(number)).font(Fonts.fraunces(18.4, weight: .regular, italic: true)).foregroundStyle(gold)
                    Text("· \(title)").font(Fonts.inter(15.2, weight: .medium)).foregroundStyle(cream.opacity(0.62)).lineLimit(1)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle().fill(cream.opacity(0.06))
                    Circle().stroke(cream.opacity(0.2), lineWidth: 1)
                    IconView(name: "ic_nav_close", color: cream).frame(width: 18, height: 18)
                }
                .frame(width: 40, height: 40)
                .pressable(tag: "projector-close", action: onClose)
                .accessibilityLabel("Salir de la proyección")
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            GeometryReader { geo in
                ZStack {
                    Color.clear
                    if idx == 0 {
                        VStack(spacing: 0) {
                            Text(String(number)).font(Fonts.fraunces(96, weight: .bold, italic: true)).foregroundStyle(gold)
                            Spacer().frame(height: 14)
                            Text(title).font(Fonts.fraunces(34, weight: .medium)).foregroundStyle(cream).multilineTextAlignment(.center)
                            if let bibleRef {
                                Spacer().frame(height: 12)
                                Text(bibleRef).font(Fonts.fraunces(17, weight: .regular, italic: true)).foregroundStyle(cream.opacity(0.7))
                            }
                            Spacer().frame(height: 36)
                            Text("→ o toca la pantalla para empezar").font(Fonts.inter(14.4, weight: .medium)).foregroundStyle(cream.opacity(0.45))
                        }
                        .padding(.horizontal, 16)
                    } else {
                        let slide = slides[idx - 1]
                        // Fit the stanza to the stage: bounded by line count and by the longest line.
                        let longest = max(12, slide.lines.map(\.count).max() ?? 12)
                        let byHeight = (geo.size.height - 40) / (CGFloat(slide.lines.count) * 1.34)
                        let byWidth = geo.size.width * 0.9 / (CGFloat(longest) * 0.5)
                        let size = max(16, min(byHeight, byWidth, 76.8))
                        VStack(spacing: 16) {
                            Text(slide.label.uppercased()).font(Fonts.inter(12, weight: .bold)).tracking(3.4).foregroundStyle(gold)
                            Text(slide.lines.joined(separator: "\n"))
                                .font(Fonts.fraunces(size, weight: .medium, italic: slide.isChorus))
                                .lineSpacing(size * 0.34 - size * 0.2)
                                .foregroundStyle(slide.isChorus ? Color(hex: 0xF1E3C0) : cream)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let left = location.x < geo.size.width / 3
                    idx = min(max(left ? idx - 1 : idx + 1, 0), total - 1)
                }
                .uiId("projector-stage")
            }

            HStack {
                ProjNav(label: "← Anterior", enabled: idx > 0, tag: "projector-prev") { idx = max(idx - 1, 0) }
                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<total, id: \.self) { i in
                        Circle().fill(i == idx ? gold : cream.opacity(0.22)).frame(width: i == idx ? 9 : 7, height: i == idx ? 9 : 7)
                    }
                }
                Spacer()
                ProjNav(label: "Siguiente →", enabled: idx < total - 1, tag: "projector-next") { idx = min(idx + 1, total - 1) }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(
            RadialGradient(colors: [Color(hex: 0x1D2A1F), Color(hex: 0x0C120D)], center: .top, startRadius: 0, endRadius: 1200).ignoresSafeArea()
        )
        .uiId("projector")
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

private struct ProjNav: View {
    let label: String
    let enabled: Bool
    let tag: String
    let action: () -> Void
    var body: some View {
        Text(label).font(Fonts.inter(13.6, weight: .medium)).foregroundStyle(cream)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Capsule().fill(cream.opacity(0.06)))
            .overlay(Capsule().stroke(cream.opacity(0.2), lineWidth: 1))
            .opacity(enabled ? 1 : 0.3)
            .pressable(enabled: enabled, tag: tag, action: action)
    }
}
