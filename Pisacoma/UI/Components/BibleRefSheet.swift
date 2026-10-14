import SwiftUI

/**
 The lesson page's verse popup (`.popup-card`): book + chapter:verses tag, the reference as
 written, and the verses from the bundled Reina-Valera 1960, one section per `;` span.
 */
struct BibleRefSheet: View {
    let refKey: String
    let display: String
    @EnvironmentObject private var app: AppModel
    @State private var loaded: [(RefSection, [(Int, String)])]? = nil

    var body: some View {
        let (book, sections) = LessonMarkdown.decodeRef(refKey)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EyebrowLine(BibleRefs.bookName(book) + " " + sections.map { "\($0.chapter):\($0.from)" + ($0.to != $0.from ? "–\($0.to)" : "") }.joined(separator: "; "), color: Tokens.sage, size: 10.5)
                Spacer().frame(height: 6)
                Text(display).font(Fonts.fraunces(22, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                Spacer().frame(height: 16)
                Hairline(alpha: 0.18)
                Spacer().frame(height: 16)
                if let data = loaded {
                    if data.allSatisfy({ $0.1.isEmpty }) {
                        Text("Versículo no encontrado.").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText)
                    } else {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, pair in
                            let (s, verses) = pair
                            if data.count > 1 {
                                EyebrowLine("Cap. \(s.chapter):\(s.from)" + (s.to != s.from ? "–\(s.to)" : ""), color: Tokens.sageText, size: 10)
                                Spacer().frame(height: 8)
                            }
                            ForEach(verses, id: \.0) { n, text in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(String(n)).font(Fonts.fraunces(13, weight: .bold, italic: true)).foregroundStyle(Ochre.label).frame(width: 24, alignment: .leading).padding(.top, 3)
                                    Text(text).font(Fonts.fraunces(17, weight: .regular)).lineSpacing(8).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.bottom, 10)
                            }
                            Spacer().frame(height: 8)
                        }
                    }
                } else {
                    Text("Cargando versículo…").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22).padding(.top, 28).padding(.bottom, 24)
        }
        .background(Tokens.cream.ignoresSafeArea())
        .accessibilityIdentifier("bible-sheet")
        .task(id: refKey) {
            var out: [(RefSection, [(Int, String)])] = []
            for s in sections { out.append((s, (try? await app.bible.verses(book, s.chapter, s.from, s.to)) ?? [])) }
            loaded = out
        }
    }
}
