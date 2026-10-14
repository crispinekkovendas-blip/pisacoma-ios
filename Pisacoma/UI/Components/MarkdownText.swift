import SwiftUI

/// The `pisacoma://ref/<key>` links the body text carries for its Bible references.
enum RefLinks {
    static let scheme = "pisacoma"
    static func url(_ key: String) -> URL { URL(string: "\(scheme)://ref/\(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)")! }
    static func key(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "ref" else { return nil }
        return String(url.path.dropFirst()).removingPercentEncoding
    }
}

/**
 Renders a lesson day (`.content` on the site): headings in Fraunces, paragraphs in Inter at
 the chosen size, the memory-verse quote, the backtick prompt box, and Bible references as
 sage underlined spans that call `onRef` with the reference key.
 */
struct MarkdownText: View {
    let blocks: [MdBlock]
    let scale: CGFloat
    let onRef: (String) -> Void

    var body: some View {
        let base = 16 * scale
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                switch b {
                case let .heading(level, text):
                    Spacer().frame(height: level <= 3 ? 26 : 22)
                    Text(text)
                        .font(Fonts.fraunces(level <= 3 ? base * 1.3 : base * 1.12, weight: level <= 3 ? .semibold : .medium))
                        .tracking(-0.015 * base)
                        .foregroundStyle(Tokens.inkDeep)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer().frame(height: 10)
                case let .paragraph(inline):
                    RefText(inline: inline, base: base)
                    Spacer().frame(height: base * 0.9)
                case let .quote(label, inline):
                    VStack(alignment: .leading, spacing: 0) {
                        if let label {
                            EyebrowLine("— \(label)", color: Ochre.label, size: 10.5)
                            Spacer().frame(height: 8)
                        }
                        RefText(inline: inline, base: base * 1.05, weight: .regular, color: Tokens.forest, serif: true, italic: true, lineMultiple: 1.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFBF9EF, alpha: 0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xB8924F, alpha: 0.35), lineWidth: 1))
                    Spacer().frame(height: base * 1.1)
                case let .prompt(inline):
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle().fill(Tokens.sage).frame(width: 3)
                        RefText(inline: inline, base: base, weight: .medium, color: Tokens.forest, serif: true)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Tokens.sageA(0.08))
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 12, topTrailingRadius: 12))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
                    Spacer().frame(height: base * 1.1)
                case let .bullet(inline):
                    HStack(alignment: .top, spacing: 0) {
                        Text("•").font(Fonts.inter(base)).foregroundStyle(Tokens.sage).frame(width: 18, alignment: .leading)
                        RefText(inline: inline, base: base)
                    }
                    .padding(.bottom, 6)
                case .rule:
                    Spacer().frame(height: 8)
                    Hairline(alpha: 0.18)
                    Spacer().frame(height: 8)
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let key = RefLinks.key(from: url) { onRef(key); return .handled }
            return .systemAction
        })
        .accessibilityIdentifier("lesson-content")
    }
}

/// Body text with the reference spans styled and tappable (site `.es-ref` buttons).
struct RefText: View {
    let inline: Inline
    let base: CGFloat
    var weight: Font.Weight = .regular
    var color: Color = Tokens.ink
    var serif = false
    var italic = false
    var lineMultiple: CGFloat = 1.72

    var body: some View {
        Text(attributed)
            .lineSpacing(base * (lineMultiple - 1.2))
            .foregroundStyle(color)
            .tint(Tokens.sage)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("md-text")
    }

    private var attributed: AttributedString {
        var a = AttributedString(inline.text)
        a.font = serif ? Fonts.fraunces(base, weight: weight, italic: italic) : Fonts.inter(base, weight: weight)
        let ns = inline.text as NSString
        func range(_ start: Int, _ end: Int) -> Range<AttributedString.Index>? {
            guard start >= 0, end <= ns.length, start < end else { return nil }
            let s = String(ns.substring(to: start))
            let m = String(ns.substring(with: NSRange(location: start, length: end - start)))
            let lower = a.index(a.startIndex, offsetByCharacters: s.count)
            let upper = a.index(lower, offsetByCharacters: m.count)
            return lower..<upper
        }
        for sp in inline.spans {
            if let r = range(sp.start, sp.end) {
                a[r].font = serif ? Fonts.fraunces(base, weight: sp.bold ? .bold : weight, italic: !sp.bold || italic) : Fonts.inter(base, weight: sp.bold ? .bold : weight)
                if !sp.bold && !serif { a[r].font = Fonts.fraunces(base, weight: weight, italic: true) }
            }
        }
        for ref in inline.refs {
            if let r = range(ref.start, ref.end) {
                a[r].link = RefLinks.url(ref.key)
                a[r].foregroundColor = Tokens.sage
                a[r].underlineStyle = .single
                a[r].font = serif ? Fonts.fraunces(base, weight: .semibold, italic: italic) : Fonts.inter(base, weight: .semibold)
            }
        }
        return a
    }
}
