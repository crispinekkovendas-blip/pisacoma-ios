import SwiftUI

/// The site's /himnario: hero, three hymnal tabs, search, «última visita», «Himnos populares», «Ir a», the typeset list.
struct HymnalIndexView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var model: HymnalModel

    init() { _model = StateObject(wrappedValue: HymnalModel(app: AppModel.shared)) }

    var body: some View {
        let s = model.state
        let filtered = s.filtered
        let last = s.rows.last?.number ?? 1
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header(s)
                    if !s.isSearching && !s.recentForVariant.isEmpty { recent(s) }
                    if !s.isSearching && !s.featured.isEmpty { picks(s) }
                    if !s.isSearching && s.ranges.count > 1 { ranges(s, proxy: proxy) }
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(String(filtered.count)).font(Fonts.fraunces(17.6, weight: .bold, italic: true)).foregroundStyle(Tokens.inkDeep)
                        EyebrowLine(filtered.count == 1 ? "himno" : "himnos", color: Tokens.sageText, size: 11, tracking: 1.8)
                        if !s.query.isEmpty { Text("para «\(s.query)»").font(Fonts.fraunces(11, weight: .regular, italic: true)).foregroundStyle(Tokens.sage) }
                    }
                    .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 18)
                    .uiId("hymn-count")
                    OrnamentRule().padding(.horizontal, 20)
                    ForEach(Array(filtered.enumerated()), id: \.element.number) { i, h in
                        let isBreak = !s.isSearching && (h.number - 1) % HymnalUi.rangeSize == 0 && h.number > 1
                        if isBreak { rangeBreak(h.number, last: last) }
                        HymnIndexRow(row: h, first: i == 0) { router.go(.hymn(variant: s.variant.slug, number: h.number)) }
                            .id("row-\(h.number)")
                    }
                    Spacer().frame(height: 50)
                    SiteFooter()
                }
            }
            .uiId("hymn-list")
        }
        .onAppear { model.refreshRecent() }
    }

    private func header(_ s: HymnalUi) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 44)
            EyebrowLine("— Himnario · Canto congregacional")
            Spacer().frame(height: 18)
            PageTitle(titleWithEm("Tres himnarios.", "Una sola alabanza."))
            Spacer().frame(height: 22)
            Lede("Más de 1.800 himnos en español y portugués, con letras completas, referencias bíblicas y audio. Selecciona un himnario abajo y empieza a cantar.")
            Spacer().frame(height: 22)
            VStack(spacing: 10) {
                ForEach(Array(HymnVariant.allCases.enumerated()), id: \.element) { i, v in
                    VariantTab(index: i + 1, variant: v, active: v == s.variant) { model.select(v) }
                }
            }
            Spacer().frame(height: 16)
            SearchField(value: Binding(get: { model.state.query }, set: { model.query($0) }), placeholder: "Buscar por número, título o pasaje bíblico…", tag: "hymn-search")
            Spacer().frame(height: 22)
        }
        .padding(.horizontal, 20)
    }

    private func recent(_ s: HymnalUi) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Color(hex: 0xB8924F, alpha: 0.22)).frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLine("— última visita", color: Ochre.label, size: 10)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        ForEach(Array(s.recentForVariant.enumerated()), id: \.element.id) { i, r in
                            if i > 0 { Text("·").font(Fonts.fraunces(14, weight: .regular, italic: true)).foregroundStyle(Tokens.sageA(0.35)) }
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text(String(r.number)).font(Fonts.fraunces(15.2, weight: .bold, italic: true)).foregroundStyle(Ochre.label)
                                Text(r.title).font(Fonts.fraunces(14.7, weight: .medium)).foregroundStyle(Tokens.forest).lineLimit(1)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .pressable(scale: 0.98, tag: "recent-\(r.number)") { router.go(.hymn(variant: r.variant, number: r.number)) }
                        }
                    }
                }
            }
            .padding(.horizontal, 4).padding(.top, 12).padding(.bottom, 14)
            Rectangle().fill(Color(hex: 0xB8924F, alpha: 0.22)).frame(height: 1)
        }
        .background(LinearGradient(colors: [Color(hex: 0xF8F0D7, alpha: 0.55), .clear], startPoint: .leading, endPoint: .trailing))
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 30)
    }

    private func picks(_ s: HymnalUi) -> some View {
        let lbl: String = { switch s.variant { case .es: return "Himno"; case .pt: return "Hino"; case .ptNovo: return "Hino · NHA" } }()
        return VStack(alignment: .leading, spacing: 0) {
            OrnamentRule()
            VStack(alignment: .leading, spacing: 0) {
                EyebrowLine("— selección del editor", color: Ochre.label, size: 10.5)
                Spacer().frame(height: 10)
                PageTitle(titleWithEm("Himnos", "populares", size: 24.8), size: 24.8)
                Spacer().frame(height: 10)
                Text("Ocho himnos amados de la congregación — " + (s.variant == .es ? "para empezar a cantar" : "para começar a cantar") + ".")
                    .font(Fonts.fraunces(14.7, weight: .regular, italic: true)).lineSpacing(5).foregroundStyle(Tokens.sageText)
                Spacer().frame(height: 22)
                ForEach(Array(s.featured.enumerated()), id: \.element.number) { i, h in
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", i + 1)).font(Fonts.fraunces(24.8, weight: .bold, italic: true)).tracking(-0.04 * 24.8).foregroundStyle(Ochre.numeral).frame(width: 38, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(h.title).font(Fonts.fraunces(16.8, weight: .medium)).foregroundStyle(Tokens.inkDeep).lineLimit(2)
                            HStack(alignment: .lastTextBaseline, spacing: 7) {
                                Text("\(lbl.uppercased()) \(h.number)").font(Fonts.fraunces(10.6, weight: .semibold)).tracking(0.6).foregroundStyle(Tokens.sage)
                                if let ref = h.bibleRef {
                                    Text("·").font(Fonts.fraunces(12)).foregroundStyle(Tokens.sageA(0.4))
                                    Text(ref).font(Fonts.fraunces(12.5, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13)
                    .pressable(scale: 0.99, tag: "pick-\(h.number)") { router.go(.hymn(variant: s.variant.slug, number: h.number)) }
                    Rectangle().fill(Tokens.sageA(0.12)).frame(height: 1).padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 22)
            OrnamentRule()
        }
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 38)
    }

    private func ranges(_ s: HymnalUi, proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 12) {
            EyebrowLine("Ir a", color: Tokens.sageText, size: 10.5, tracking: 2.2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(s.ranges, id: \.lowerBound) { r in
                        Text("\(r.lowerBound)–\(r.upperBound)")
                            .font(Fonts.inter(11.5, weight: .semibold)).foregroundStyle(Tokens.forest)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.6)))
                            .overlay(Capsule().stroke(Tokens.sageA(0.22), lineWidth: 1))
                            .pressable {
                                if let first = s.filtered.first(where: { $0.number >= r.lowerBound }) { withAnimation { proxy.scrollTo("row-\(first.number)", anchor: .top) } }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xFBF9EF, alpha: 0.94)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.sageA(0.16), lineWidth: 1))
        .padding(.horizontal, 20).padding(.bottom, 18)
    }

    private func rangeBreak(_ number: Int, last: Int) -> some View {
        let start = (number - 1) / HymnalUi.rangeSize * HymnalUi.rangeSize + 1
        let end = min(start + HymnalUi.rangeSize - 1, last)
        let line = LinearGradient(colors: [.clear, Tokens.sageA(0.22), .clear], startPoint: .leading, endPoint: .trailing)
        return HStack(spacing: 18) {
            line.frame(height: 1)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(String(start)).font(Fonts.fraunces(20, weight: .bold, italic: true)).foregroundStyle(Ochre.numeral)
                Text("✦").font(.system(size: 11)).foregroundStyle(Color(hex: 0xB8924F, alpha: 0.6))
                Text("\(start)–\(end)").font(Fonts.fraunces(11.8, weight: .medium, italic: true)).tracking(0.5).foregroundStyle(Tokens.sageText)
            }
            line.frame(height: 1)
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 16)
    }
}

/// `.tab`: numeral · label / sub; the active one is the sage→forest gradient.
private struct VariantTab: View {
    let index: Int
    let variant: HymnVariant
    let active: Bool
    let onClick: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("0\(index)").font(Fonts.fraunces(16, weight: .bold, italic: true)).foregroundStyle(active ? Color(hex: 0xE8D091) : Ochre.label).frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(variant.tabLabel).font(Fonts.fraunces(16.8, weight: .semibold)).tracking(-0.2).foregroundStyle(active ? Tokens.cream : Tokens.inkDeep)
                Text(variant.tabSub.uppercased()).font(Fonts.inter(10, weight: .semibold)).tracking(1.4).foregroundStyle(active ? Tokens.cream.opacity(0.7) : Tokens.sageText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(active ? AnyShapeStyle(LinearGradient(colors: [Tokens.sage, Tokens.forest], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.55)))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? Tokens.forest : Tokens.sageA(0.18), lineWidth: 1))
        .pressable(scale: 0.985, tag: "tab-\(variant.slug)", action: onClick)
    }
}

/// `.list .row`: ochre italic numeral, Fraunces title, italic reference, faint arrow.
struct HymnIndexRow: View {
    let row: HymnRow
    let first: Bool
    let onClick: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !first { Rectangle().fill(Tokens.sageA(0.10)).frame(height: 1) }
            HStack(spacing: 16) {
                Text(String(row.number)).font(Fonts.fraunces(22.7, weight: .bold, italic: true)).tracking(-0.035 * 22.7).foregroundStyle(Ochre.numeral).frame(width: 50, alignment: .trailing)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title).font(Fonts.fraunces(16, weight: .medium)).foregroundStyle(Tokens.ink).lineLimit(2)
                    if let ref = row.bibleRef { Text(ref).font(Fonts.fraunces(11.5, weight: .regular, italic: true)).foregroundStyle(Color(hex: 0x657158)).lineLimit(1) }
                }
                Spacer(minLength: 0)
                IconView(name: "ic_nav_arrow", color: Tokens.sage).frame(width: 14, height: 14).opacity(0.5).frame(width: 26, height: 26)
            }
            .padding(.trailing, 8).padding(.vertical, 14)
            .pressable(scale: 0.99, tag: "hymn-row-\(row.number)", action: onClick)
        }
        .padding(.horizontal, 20)
    }
}
