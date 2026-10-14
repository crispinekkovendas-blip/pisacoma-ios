import SwiftUI

private let groups = [("bible", "Biblia"), ("hymns", "Himnos"), ("egw", "Elena G. de White"), ("lessons", "Escuela Sabática")]
private let preview = 6
private let examples = ["307", "Roca de la eternidad", "Juan 3:16", "Camino a Cristo", "falsos maestros"]

/// The site's /buscar: one field over the bundled index, four groups of typeset rows, «Ver N resultados».
struct SearchView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var router: Router
    @State private var index: SearchIndex? = nil
    @State private var query = ""
    @State private var expanded: Set<String> = []

    var body: some View {
        let results = Search.search(index, query)
        let hasQuery = !query.trimmingCharacters(in: .whitespaces).isEmpty
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 44)
                    EyebrowLine("— Buscar · Todo el sitio")
                    Spacer().frame(height: 18)
                    PageTitle(titleWithEm("Busca en", "todo el sitio."))
                    Spacer().frame(height: 22)
                    Lede("Himnos por número o título, capítulos de Elena G. de White, lecciones del trimestre y pasajes de la Biblia — desde un solo lugar.")
                    Spacer().frame(height: 26)
                    SearchField(
                        value: Binding(get: { query }, set: { query = $0; expanded = [] }),
                        placeholder: "Himno, capítulo, lección o Juan 3:16…",
                        tag: "search-input",
                        onSearch: { if let first = results.bible.first ?? results.hymns.first ?? results.egw.first ?? results.lessons.first { open(first.href) } },
                        clearable: true
                    )
                    Spacer().frame(height: 12)
                    Text(statusText(hasQuery: hasQuery, results: results))
                        .font(Fonts.fraunces(13.5, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
                        .uiId("search-status")
                    if !hasQuery && index != nil {
                        Spacer().frame(height: 14)
                        FlowLayout(spacing: 8) {
                            ForEach(examples, id: \.self) { ex in
                                Text(ex).font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Tokens.forest)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Color.white.opacity(0.6)))
                                    .overlay(Capsule().stroke(Tokens.sageA(0.22), lineWidth: 1))
                                    .pressable(scale: 0.97, tag: "example-\(ex)") { query = ex }
                            }
                        }
                    }
                    Spacer().frame(height: 22)
                }
                .padding(.horizontal, 20)
                ForEach(groups, id: \.0) { key, label in
                    let hits: [SearchHit] = { switch key { case "bible": return results.bible; case "hymns": return results.hymns; case "egw": return results.egw; default: return results.lessons } }()
                    if !hits.isEmpty {
                        let open = expanded.contains(key)
                        let shown = Array(hits.prefix(open ? 60 : preview))
                        HStack(spacing: 12) {
                            EyebrowLine("— \(label)", color: Tokens.sage, size: 10.5)
                            OrnamentRule()
                            Text(String(hits.count)).font(Fonts.fraunces(14, weight: .bold, italic: true)).foregroundStyle(Ochre.label)
                        }
                        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                        ForEach(Array(shown.enumerated()), id: \.offset) { i, h in
                            VStack(spacing: 0) {
                                if i > 0 { Rectangle().fill(Tokens.sageA(0.10)).frame(height: 1) }
                                HStack(spacing: 14) {
                                    Text(h.num).font(Fonts.fraunces(20, weight: .bold, italic: true)).tracking(-0.03 * 20).foregroundStyle(Ochre.numeral).frame(width: 48, alignment: .trailing).lineLimit(1)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(h.title).font(Fonts.fraunces(16, weight: .medium)).foregroundStyle(Tokens.ink).lineLimit(2)
                                        Text(h.caption).font(Fonts.fraunces(11.5, weight: .regular, italic: true)).foregroundStyle(Color(hex: 0x657158)).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    IconView(name: "ic_nav_arrow", color: Tokens.sage).frame(width: 14, height: 14).opacity(0.5).frame(width: 26, height: 26)
                                }
                                .padding(.trailing, 8).padding(.vertical, 13)
                                .pressable(scale: 0.99, tag: "hit-\(h.href)") { self.open(h.href) }
                            }
                            .padding(.horizontal, 20)
                        }
                        if hits.count > preview && !open {
                            Text("Ver \(min(hits.count, 60)) \(label == "Himnos" ? "himnos" : "resultados") ↓")
                                .font(Fonts.inter(13, weight: .semibold)).foregroundStyle(Tokens.sage)
                                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 18)
                                .pressable(scale: 0.98, tag: "more-\(key)") { expanded.insert(key) }
                        }
                    }
                }
                Spacer().frame(height: 50)
                SiteFooter()
            }
        }
        .uiId("search-page")
        .task {
            do { index = try await app.search.index() } catch let e as ContentMissing { ContentErrors.report(e, app: app) } catch {}
        }
    }

    private func statusText(hasQuery: Bool, results: SearchGroups) -> String {
        if index == nil { return "Cargando el índice…" }
        if hasQuery && results.total == 0 { return "Sin resultados para «\(query.trimmingCharacters(in: .whitespaces))»." }
        if hasQuery { return "\(results.total) \(results.total == 1 ? "resultado" : "resultados") · Enter abre el primero" }
        return "Consejo: toca la lupa de arriba desde cualquier pantalla para buscar."
    }

    private func open(_ href: String) { if let r = Route.parse(href) { router.go(r) } }
}

/// A wrapping row (the site's flex-wrap chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
