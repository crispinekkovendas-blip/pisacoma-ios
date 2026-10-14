import SwiftUI

/// The site's /biblia: hero, «Lectura» picker button + tools, the chapter, pager, book/chapter picker, drawer.
struct BibleView: View {
    @EnvironmentObject private var router: Router
    @Environment(\.openURL) private var openURL
    @StateObject private var model: BibleModel
    @State private var picker = false
    @State private var pickerBook = 0 // 0 = book list
    @State private var testament = "NT"
    @State private var drawer: String? = nil

    init(book: Int?, chapter: Int?, verse: Int?) {
        _model = StateObject(wrappedValue: BibleModel(app: AppModel.shared, book: book, chapter: chapter, verse: verse))
    }

    var body: some View {
        let s = model.state
        if let cur = s.book {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header(s, cur: cur)
                        ForEach(s.verses) { v in
                            let target = v.n == s.targetVerse
                            verseRow(v, scale: s.scale, target: target)
                                .id("verse-\(v.n)")
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer().frame(height: 40)
                            Hairline(alpha: 0.18)
                            Spacer().frame(height: 22)
                            HStack {
                                LessonPagerPill(label: "← Anterior") { if !s.isFirst { model.prev() } }.opacity(s.isFirst ? 0.35 : 1)
                                Spacer()
                                Text("\(cur.abbr) · \(s.chapter) / \(cur.chapters)").font(Fonts.fraunces(13, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
                                Spacer()
                                LessonPagerPill(label: "Siguiente →") { if !s.isLast { model.next() } }.opacity(s.isLast ? 0.35 : 1)
                            }
                            Spacer().frame(height: 60)
                        }
                        .padding(.horizontal, 20)
                        SiteFooter()
                    }
                }
                .accessibilityIdentifier("bible-list")
                .onChange(of: s.loading) { loading in
                    if !loading {
                        if s.targetVerse > 0 { withAnimation { proxy.scrollTo("verse-\(min(s.targetVerse, s.verses.count))", anchor: .center) } } else { proxy.scrollTo("bible-top", anchor: .top) }
                    }
                }
            }
            .sheet(isPresented: $picker) { pickerView(s).presentationDetents([.large]).presentationDragIndicator(.visible) }
            .sheet(isPresented: Binding(get: { drawer != nil }, set: { if !$0 { drawer = nil } })) {
                drawerView(s, cur: cur).presentationDetents([.large]).presentationDragIndicator(.visible)
            }
        } else {
            Color.clear
        }
    }

    private func header(_ s: BibleUi, cur: BibleBook) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 44).id("bible-top")
            EyebrowLine("— Reina-Valera 1960 · Biblia completa")
            Spacer().frame(height: 18)
            PageTitle(titleWithEm("La", "Palabra", tail: ",\nlibro por libro."))
            Spacer().frame(height: 22)
            Lede("Sesenta y seis libros, dos testamentos, una sola voz. Pulsa el título de abajo para saltar a cualquier libro y capítulo.")
            Spacer().frame(height: 26)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        EyebrowLine("Lectura", color: Tokens.sageText, size: 10, tracking: 2)
                        (Text(cur.name + " ").font(Fonts.fraunces(22, weight: .semibold)) + Text(String(s.chapter)).font(Fonts.fraunces(22, weight: .semibold, italic: true)).foregroundColor(Ochre.numeral))
                            .foregroundStyle(Tokens.inkDeep)
                    }
                    Spacer()
                    IconView(name: "ic_nav_arrow", color: Tokens.sage).frame(width: 18, height: 18)
                }
                .padding(.horizontal, 6).padding(.vertical, 6)
                .pressable(scale: 0.985, tag: "bible-title") { pickerBook = s.bookNum; testament = s.bookNum >= 40 ? "NT" : "AT"; picker = true }
                HStack(spacing: 6) {
                    ToolbarIcon(icon: "ic_back", label: "Capítulo anterior", tag: "bible-prev") { if !s.isFirst { model.prev() } }.opacity(s.isFirst ? 0.35 : 1)
                    ToolbarIcon(icon: "ic_nav_arrow", label: "Capítulo siguiente", tag: "bible-next") { if !s.isLast { model.next() } }.opacity(s.isLast ? 0.35 : 1)
                    Rectangle().fill(Tokens.sageA(0.2)).frame(width: 1, height: 22)
                    TextSizeControls(onSmaller: { model.smaller() }, onLarger: { model.larger() })
                    Rectangle().fill(Tokens.sageA(0.2)).frame(width: 1, height: 22)
                    let sel = s.verses.first { $0.n == s.targetVerse }
                    ToolbarIcon(icon: "ic_share", label: sel.map { "Compartir \(cur.name) \(s.chapter):\($0.n)" } ?? "Compartir capítulo", tag: "bible-share") {
                        let text = sel.map { "«\($0.text)» — \(cur.name) \(s.chapter):\($0.n) (RVR 1960)" } ?? "\(cur.name) \(s.chapter) · Biblia Reina-Valera 1960"
                        let url = "\(AudioUrls.site)/biblia/?libro=\(s.bookNum)&cap=\(s.chapter)" + (sel.map { "&v=\($0.n)" } ?? "")
                        let vc = UIActivityViewController(activityItems: ["\(text)\n\(url)"], applicationActivities: nil)
                        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.rootViewController?.topMost.present(vc, animated: true)
                    }
                    ToolbarIcon(icon: "ic_bookmark", label: s.isBookmarked ? "Quitar marcador" : "Guardar capítulo", active: s.isBookmarked, tag: "bible-bookmark") { model.toggleBookmark() }
                    HStack(spacing: 6) {
                        IconView(name: "ic_note", color: Tokens.forest).frame(width: 16, height: 16)
                        Text("Notas").font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Tokens.forest)
                        if s.currentHasNotes { Circle().fill(Ochre.numeral).frame(width: 6, height: 6) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Tokens.sageA(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tokens.sageA(0.2), lineWidth: 1))
                    .pressable(tag: "bible-panel") { drawer = "notes" }
                    .accessibilityLabel("Abrir panel de notas, marcadores y recientes")
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xFBF9EF, alpha: 0.94)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Tokens.sageA(0.18), lineWidth: 1))
            Spacer().frame(height: 30)
            HStack(spacing: 14) {
                Text(String(s.chapter)).font(Fonts.fraunces(44, weight: .bold, italic: true)).foregroundStyle(Ochre.numeral)
                Rectangle().fill(Tokens.sageA(0.3)).frame(width: 28, height: 1)
                Text(cur.name).font(Fonts.fraunces(18, weight: .medium)).foregroundStyle(Tokens.inkDeep)
                Spacer(minLength: 0)
            }
            Spacer().frame(height: 8)
            HStack(spacing: 6) {
                Text("Leer en aimara").font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Tokens.sage)
                IconView(name: "ic_external", color: Tokens.sage).frame(width: 12, height: 12)
            }
            .padding(.vertical, 4)
            .pressable(scale: 0.98, tag: "bible-aymara") { if let u = URL(string: model.aymaraUrl()) { openURL(u) } }
            if s.currentHasNotes {
                Spacer().frame(height: 12)
                HStack(spacing: 6) {
                    IconView(name: "ic_note", color: Ochre.label).frame(width: 13, height: 13)
                    Text("Has tomado notas en este capítulo").font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Ochre.label)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Color(hex: 0xB8924F, alpha: 0.2)))
                .pressable { drawer = "notes" }
            }
            Spacer().frame(height: 18)
            if s.loading { Text("Cargando \(cur.name)…").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText) }
            else if s.verses.isEmpty { Text("Capítulo no disponible.").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText) }
        }
        .padding(.horizontal, 20)
    }

    private func verseRow(_ v: Verse, scale: CGFloat, target: Bool) -> some View {
        (Text("\(v.n) ").font(Fonts.inter(11 * scale, weight: .bold)).foregroundColor(Ochre.label).baselineOffset(6 * scale) + Text(v.text).font(Fonts.fraunces(17 * scale, weight: .regular)))
            .lineSpacing(13 * scale)
            .foregroundStyle(Tokens.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5).padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(target ? Color(hex: 0xF8F0D7, alpha: 0.25) : Color.clear))
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture { model.tapVerse(v.n) }
            .accessibilityIdentifier("verse-\(v.n)")
    }

    @ViewBuilder
    private func pickerView(_ s: BibleUi) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if pickerBook == 0 {
                EyebrowLine("— Selecciona un libro", color: Tokens.sage)
                Spacer().frame(height: 14)
                HStack(spacing: 8) {
                    ForEach([("AT", "Antiguo Testamento", 39), ("NT", "Nuevo Testamento", 27)], id: \.0) { id, label, n in
                        let active = testament == id
                        HStack(spacing: 8) {
                            Text(String(n)).font(Fonts.fraunces(15, weight: .bold, italic: true)).foregroundStyle(active ? Color(hex: 0xE8D091) : Ochre.label)
                            Text(label).font(Fonts.inter(12, weight: .semibold)).foregroundStyle(active ? Tokens.cream : Tokens.forest)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(active ? Tokens.forest : Tokens.sageA(0.08)))
                        .pressable(scale: 0.98, tag: "picker-tab-\(id)") { testament = id }
                    }
                }
                Spacer().frame(height: 12)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(s.books.filter { (testament == "AT") == $0.isOldTestament }, id: \.num) { b in
                            let current = b.num == s.bookNum
                            HStack(spacing: 12) {
                                Text(b.abbr).font(Fonts.fraunces(13, weight: .bold, italic: true)).foregroundStyle(Ochre.label).frame(width: 34, alignment: .leading)
                                Text(b.name).font(Fonts.fraunces(16, weight: .medium)).foregroundStyle(Tokens.ink)
                                Spacer()
                                Text(String(b.chapters)).font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10).fill(current ? Tokens.sageA(0.12) : Color.clear))
                            .pressable(scale: 0.99, tag: "picker-book-\(b.num)") { pickerBook = b.num }
                        }
                    }
                }
            } else if let pb = s.books.first(where: { $0.num == pickerBook }) {
                HStack(spacing: 6) {
                    IconView(name: "ic_back", color: Tokens.sage).frame(width: 14, height: 14)
                    Text("Cambiar libro").font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Tokens.sage)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .pressable(scale: 0.98, tag: "picker-books") { pickerBook = 0 }
                Spacer().frame(height: 12)
                HStack(spacing: 14) {
                    Text(pb.abbr).font(Fonts.fraunces(26, weight: .bold, italic: true)).foregroundStyle(Ochre.numeral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pb.name).font(Fonts.fraunces(20, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                        Text("\(pb.chapters) capítulos · \(pb.num < 40 ? "Antiguo" : "Nuevo") Testamento").font(Fonts.inter(12)).foregroundStyle(Tokens.sageText)
                    }
                }
                Spacer().frame(height: 16)
                ScrollView {
                    let cols = [GridItem(.adaptive(minimum: 46), spacing: 8)]
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(1...pb.chapters, id: \.self) { c in
                            let current = pb.num == s.bookNum && c == s.chapter
                            Text(String(c)).font(Fonts.fraunces(15, weight: .semibold)).foregroundStyle(current ? Tokens.cream : Tokens.forest)
                                .frame(width: 46, height: 46)
                                .background(RoundedRectangle(cornerRadius: 10).fill(current ? Tokens.forest : Color.white.opacity(0.55)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(current ? Tokens.forest : Tokens.sageA(0.18), lineWidth: 1))
                                .pressable(scale: 0.95, tag: "picker-chapter-\(c)") { picker = false; model.open(pb.num, c) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 24)
        .background(Tokens.cream.ignoresSafeArea())
        .accessibilityIdentifier("bible-picker")
    }

    @ViewBuilder
    private func drawerView(_ s: BibleUi, cur: BibleBook) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([("notes", "Notas"), ("bookmarks", "Marcadores"), ("recent", "Recientes")], id: \.0) { id, label in
                        let active = drawer == id
                        Text(label + (id == "bookmarks" && !s.bookmarks.isEmpty ? " \(s.bookmarks.count)" : ""))
                            .font(Fonts.inter(13, weight: .semibold)).foregroundStyle(active ? Tokens.cream : Tokens.forest)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(active ? Tokens.forest : Tokens.sageA(0.08)))
                            .pressable(scale: 0.97, tag: "panel-tab-\(id)") { drawer = id }
                    }
                }
                Spacer().frame(height: 20)
                switch drawer {
                case "notes":
                    EyebrowLine("— Notas de \(cur.name) \(s.chapter)", color: Tokens.sage, size: 10.5)
                    Spacer().frame(height: 6)
                    Text(s.savedAt.map { "Guardado \(relativeTimeEs($0))" } ?? (s.notes.isEmpty ? "Empieza a escribir — guardamos automáticamente" : "Tus apuntes anteriores")).font(Fonts.inter(12)).foregroundStyle(Tokens.sageText)
                    Spacer().frame(height: 12)
                    ZStack(alignment: .topLeading) {
                        if s.notes.isEmpty { Text("Escribe lo que aprendiste, citas favoritas, aplicaciones personales…").font(Fonts.inter(14)).foregroundStyle(Color(hex: 0x9AA792)).padding(.top, 8).padding(.leading, 5) }
                        TextEditor(text: Binding(get: { model.state.notes }, set: { model.notes($0) }))
                            .font(Fonts.inter(14.5)).foregroundStyle(Tokens.ink).tint(Tokens.sage).scrollContentBackground(.hidden).frame(height: 180)
                            .accessibilityIdentifier("notes-area")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.sageA(0.2), lineWidth: 1))
                    if !s.notes.isEmpty { Text("Borrar nota").font(Fonts.inter(11, weight: .semibold)).foregroundStyle(Color(hex: 0x8A3A2A)).padding(.top, 8).pressable(scale: 0.97) { model.clearNotes() } }
                case "bookmarks":
                    if s.bookmarks.isEmpty { Text("Aún no hay marcadores. Toca el marcador de la barra para guardar un capítulo.").font(Fonts.inter(14)).lineSpacing(5).foregroundStyle(Tokens.sageText) }
                    ForEach(s.bookmarks) { bm in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(bm.bookName) \(bm.chapter)").font(Fonts.fraunces(16, weight: .medium)).foregroundStyle(Tokens.ink)
                                Text(relativeTimeEs(bm.addedAt)).font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .pressable(scale: 0.98) { drawer = nil; model.open(bm.bookNum, bm.chapter) }
                            IconView(name: "ic_nav_close", color: Tokens.sageText).frame(width: 16, height: 16).pressable { model.removeBookmark(bm.bookNum, bm.chapter) }.accessibilityLabel("Quitar marcador")
                        }
                        .padding(.vertical, 10)
                        Hairline(alpha: 0.12)
                    }
                case "recent":
                    if s.recent.isEmpty { Text("Todavía no has leído ningún capítulo.").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText) }
                    ForEach(s.recent) { r in
                        HStack {
                            Text("\(r.bookName) \(r.chapter)").font(Fonts.fraunces(16, weight: .medium)).foregroundStyle(Tokens.ink)
                            Spacer()
                            Text(relativeTimeEs(r.viewedAt)).font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                        }
                        .padding(.vertical, 10)
                        .pressable(scale: 0.98) { drawer = nil; model.open(r.bookNum, r.chapter) }
                        Hairline(alpha: 0.12)
                    }
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 28)
        }
        .background(Tokens.cream.ignoresSafeArea())
        .accessibilityIdentifier("bible-drawer")
    }
}
