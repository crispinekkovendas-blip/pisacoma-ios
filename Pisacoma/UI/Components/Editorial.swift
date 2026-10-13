import SwiftUI

// The cream pages share one editorial vocabulary (site: .eyebrow / h1 with em / .lede / rules).

/// `.eyebrow`: 11pt Inter 700 uppercase, 2.4 tracking, sage. The site writes the leading dash in the text.
struct EyebrowLine: View {
    let text: String
    var color: Color = Tokens.sage
    var size: CGFloat = 11
    var tracking: CGFloat = 2.4

    init(_ text: String, color: Color = Tokens.sage, size: CGFloat = 11, tracking: CGFloat = 2.4) {
        self.text = text; self.color = color; self.size = size; self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased())
            .font(Fonts.inter(size, weight: .bold))
            .tracking(tracking)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small uppercase Inter label used across the chrome (.brand-text span, .mm-desc, .mm-foot span).
struct Eyebrow: View {
    let text: String
    let color: Color
    var size: CGFloat = 10.5
    var tracking: CGFloat = 1.6
    var weight: Font.Weight = .semibold

    init(_ text: String, _ color: Color, size: CGFloat = 10.5, tracking: CGFloat = 1.6, weight: Font.Weight = .semibold) {
        self.text = text; self.color = color; self.size = size; self.tracking = tracking; self.weight = weight
    }

    var body: some View {
        Text(text.uppercased()).font(Fonts.inter(size, weight: weight)).tracking(tracking).foregroundStyle(color)
    }
}

/// Builds «Plain text <em>italic sage</em>» the way the site's h1s are written.
func titleWithEm(_ plain: String, _ em: String, emColor: Color = Tokens.sage, tail: String = "", size: CGFloat = 32) -> Text {
    var t = Text(plain).font(Fonts.fraunces(size, weight: .medium))
    if !em.isEmpty {
        if !plain.isEmpty && !plain.hasSuffix(" ") && !plain.hasSuffix("\n") { t = t + Text(" ").font(Fonts.fraunces(size, weight: .medium)) }
        t = t + Text(em).font(Fonts.fraunces(size, weight: .regular, italic: true)).foregroundColor(emColor)
    }
    if !tail.isEmpty { t = t + Text(tail).font(Fonts.fraunces(size, weight: .medium)) }
    return t
}

/// `.hero h1`: Fraunces 500, 32pt on a phone, line-height 1, −0.022em.
struct PageTitle: View {
    let text: Text
    var size: CGFloat = 32
    var color: Color = Tokens.inkDeep

    init(_ text: Text, size: CGFloat = 32, color: Color = Tokens.inkDeep) { self.text = text; self.size = size; self.color = color }

    var body: some View {
        text
            .tracking(size * -0.022)
            .lineSpacing(0)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// `.lede`: 16pt Inter, line-height 1.6, muted sage ink.
struct Lede: View {
    let text: String
    var color: Color = Tokens.ledeInk
    init(_ text: String, color: Color = Tokens.ledeInk) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(Fonts.inter(16)).lineSpacing(6).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}

/// The site's gradient hairline (transparent → sage → ochre → sage → transparent).
struct OrnamentRule: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Tokens.sageA(0.22), location: 0.12),
                .init(color: Color(hex: 0xB8924F, alpha: 0.5), location: 0.5),
                .init(color: Tokens.sageA(0.22), location: 0.88),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 1)
    }
}

/// A plain hairline in the sage used by the cream pages.
struct Hairline: View {
    var alpha: Double = 0.12
    var body: some View { Rectangle().fill(Tokens.sageA(alpha)).frame(height: 1) }
}
