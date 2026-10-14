import SwiftUI

/// The site's /diccionario: a word → Wiktionary definitions, suggested words, a short history.
struct DictionaryView: View {
    @State private var query = ""
    @State private var searched = ""
    @State private var loading = false
    @State private var sections: [DictSection]? = nil
    @State private var error: String? = nil
    @State private var history: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 44)
                EyebrowLine("— Diccionario · Wiccionario en español")
                Spacer().frame(height: 18)
                PageTitle(titleWithEm("Cada palabra\ntiene su", "raíz", tail: "."))
                Spacer().frame(height: 22)
                Lede("Busca cualquier palabra en español — bíblica, teológica o cotidiana. Las definiciones vienen del Wiccionario libre y se actualizan a diario.")
                Spacer().frame(height: 26)
                SearchField(value: $query, placeholder: "amor, gracia, sábado, redención…", tag: "dict-input", onSearch: { search(query) }, clearable: true)
                    .onChange(of: query) { v in if v.isEmpty { sections = nil; error = nil; searched = "" } }
                Spacer().frame(height: 10)
                Text("Buscar").font(Fonts.inter(14, weight: .semibold)).foregroundStyle(Tokens.cream)
                    .padding(.horizontal, 18).padding(.vertical, 10).background(Capsule().fill(Tokens.forest))
                    .pressable(scale: 0.97, tag: "dict-search") { search(query) }
                Spacer().frame(height: 22)
                if !history.isEmpty {
                    EyebrowLine("— Recientes", color: Tokens.sageText, size: 10.5)
                    Spacer().frame(height: 8)
                    FlowLayout(spacing: 8) { ForEach(history, id: \.self) { w in Chip(label: w) { search(w) } } }
                    Spacer().frame(height: 22)
                }
                if loading {
                    Text("Buscando «\(searched)»…").font(Fonts.fraunces(14, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText).accessibilityIdentifier("dict-loading")
                } else if let error {
                    Text(error).font(Fonts.fraunces(15, weight: .regular, italic: true)).lineSpacing(5).foregroundStyle(Color(hex: 0x8A3A2A)).accessibilityIdentifier("dict-error")
                } else if let sections {
                    Text(searched).font(Fonts.fraunces(34, weight: .semibold)).foregroundStyle(Tokens.inkDeep).accessibilityIdentifier("dict-word")
                    Spacer().frame(height: 14)
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, sec in
                        EyebrowLine(sec.partOfSpeech, color: Ochre.label, size: 10.5)
                        Spacer().frame(height: 10)
                        ForEach(Array(sec.definitions.enumerated()), id: \.offset) { i, d in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(i + 1)).font(Fonts.fraunces(16, weight: .bold, italic: true)).foregroundStyle(Ochre.numeral).frame(width: 22, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(d.definition).font(Fonts.inter(15.5)).lineSpacing(6).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
                                    ForEach(d.examples, id: \.self) { ex in
                                        Text("«\(ex)»").font(Fonts.fraunces(14, weight: .regular, italic: true)).lineSpacing(4).foregroundStyle(Tokens.sageText).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                        }
                        Spacer().frame(height: 10); Hairline(alpha: 0.14); Spacer().frame(height: 18)
                    }
                    Text("Definiciones del Wiccionario en español · CC BY-SA").font(Fonts.inter(11.5)).foregroundStyle(Tokens.sageText)
                } else {
                    EyebrowLine("— Palabras sugeridas", color: Tokens.sageText, size: 10.5)
                    Spacer().frame(height: 10)
                    FlowLayout(spacing: 8) { ForEach(Wiktionary.suggested, id: \.self) { w in Chip(label: w) { search(w) } } }
                }
                Spacer().frame(height: 50)
            }
            .padding(.horizontal, 20)
            SiteFooter()
        }
        .accessibilityIdentifier("dict-page")
    }

    private func search(_ term: String) {
        let word = term.trimmingCharacters(in: .whitespaces).lowercased()
        if word.isEmpty { return }
        searched = word; query = word; loading = true; error = nil; sections = nil
        Task {
            switch await Wiktionary.lookup(word) {
            case let .found(s):
                sections = s
                history.removeAll { $0 == word }
                history.insert(word, at: 0)
                if history.count > 6 { history.removeLast(history.count - 6) }
            case let .error(m):
                error = m
            }
            loading = false
        }
    }
}

private struct Chip: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Text(label).font(Fonts.inter(12.5, weight: .semibold)).foregroundStyle(Tokens.forest)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.white.opacity(0.6)))
            .overlay(Capsule().stroke(Tokens.sageA(0.22), lineWidth: 1))
            .pressable(scale: 0.97, tag: "word-\(label)", action: action)
    }
}
