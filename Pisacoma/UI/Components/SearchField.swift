import SwiftUI

/**
 The cream search box (`.search-wrap` + `.search` on himnario/buscar): 14 pt radius,
 parchment fill, sage glyph, Fraunces 500 input with an italic placeholder.
 */
struct SearchField: View {
    @Binding var value: String
    let placeholder: String
    var tag: String = "search-field"
    var onSearch: () -> Void = {}
    var clearable: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            IconView(name: "ic_nav_search", color: Tokens.sageSoft).frame(width: 20, height: 20)
            ZStack(alignment: .leading) {
                if value.isEmpty {
                    Text(placeholder).font(Fonts.fraunces(16.8, weight: .regular, italic: true)).foregroundStyle(Color(hex: 0x9AA792))
                }
                TextField("", text: $value)
                    .font(Fonts.fraunces(16.8, weight: .medium))
                    .foregroundStyle(Tokens.inkDeep)
                    .tint(Tokens.sage)
                    .submitLabel(.search)
                    .onSubmit(onSearch)
                    .autocorrectionDisabled()
                    .uiId(tag)
            }
            .padding(.vertical, 14)
            if clearable && !value.isEmpty {
                IconView(name: "ic_nav_close", color: Tokens.sageText).frame(width: 16, height: 16)
                    .frame(width: 36, height: 36)
                    .pressable(tag: "\(tag)-clear") { value = "" }
                    .accessibilityLabel("Limpiar")
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFBF9EF, alpha: 0.94)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Tokens.sageA(0.20), lineWidth: 1))
    }
}
