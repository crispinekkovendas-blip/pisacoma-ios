import SwiftUI

/// The site's /egw/<slug>: toolbar (TOC, back, book id, progress, tools), the chapter, done CTA, pager; the chapter list and the notes drawer as sheets.
struct EgwBookView: View {
    let slug: String
    let chapter: Int?
    @EnvironmentObject private var router: Router
    @StateObject private var model: EgwBookModel
    @State private var toc = false
    @State private var drawer: String? = nil

    init(slug: String, chapter: Int?) {
        self.slug = slug
        self.chapter = chapter
        _model = StateObject(wrappedValue: EgwBookModel(app: AppModel.shared, slug: slug, initialChapter: chapter))
    }

    var body: some View {
        let s = model.state
        if s.notFound {
            VStack(alignment: .leading, spacing: 12) {
                Text("Libro no encontrado").font(Fonts.fraunces(24)).foregroundStyle(Tokens.inkDeep)
                Text("← Volver al catálogo").font(Fonts.inter(15)).foregroundStyle(Tokens.sage).pressable { router.go(.egw) }
                Spacer()
            }
            .padding(20)
        } else if let meta = s.meta, let book = s.book, let cur = s.current {
            let accent = hexColor(meta.color)
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    ToolbarIcon(icon: "ic_chapters", label: "Capítulos", tag: "egw-chapters") { toc = true }
                    IconView(name: "ic_back", color: Tokens.sage).frame(width: 14, height: 14).frame(width: 32, height: 32)
                        .pressable(scale: 0.97, tag: "egw-back") { router.go(.egw) }.accessibilityLabel("Volver al catálogo")
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(meta.id).font(Fonts.inter(9.5, weight: .bold)).tracking(0.6).foregroundStyle(Tokens.cream).padding(.horizontal, 5).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 5).fill(accent)).lineLimit(1)
                            Text("\(cur.number)/\(s.total)").font(Fonts.inter(11, weight: .semibold)).foregroundStyle(Tokens.sageText).lineLimit(1)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Tokens.sageA(0.14))
                                Capsule().fill(accent).frame(width: geo.size.width * CGFloat(s.pct) / 100)
                            }
                        }
                        .frame(height: 3)
                    }
                    ToolbarIcon(icon: "ic_check", label: s.isDone ? "Marcar como no leído" : "Marcar como completado", active: s.isDone, tag: "chapter-done-top") { model.toggleDone() }
                    ToolbarIcon(icon: "ic_bookmark", label: s.isBookmarked ? "Quitar marcador" : "Agregar marcador", active: s.isBookmarked, tag: "egw-bookmark") { model.toggleBookmark() }
                    TextSizeControls(onSmaller: { model.smaller() }, onLarger: { model.larger() })
                    ToolbarIcon(icon: "ic_note", label: "Notas y marcadores", active: drawer != nil, tag: "egw-notes") { drawer = "notes" }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color(hex: 0xF7F4E6, alpha: 0.95))
                Hairline(alpha: 0.12)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer().frame(height: 26).id("egw-top")
                                HStack(spacing: 10) {
                                    EyebrowLine("Capítulo \(cur.number) · \(meta.id)", color: accent, size: 10.5)
                                    Rectangle().fill(Tokens.sageA(0.3)).frame(width: 18, height: 1)
                                    Text(meta.title).font(Fonts.fraunces(13, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText).lineLimit(1)
                                }
                                Spacer().frame(height: 14)
                                Text(cur.title).font(Fonts.fraunces(28, weight: .semibold)).tracking(-0.022 * 28).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("egw-chapter-title")
                                Spacer().frame(height: 22)
                            }
                            .padding(.horizontal, 20)
                            ForEach(Array(cur.paragraphs.enumerated()), id: \.offset) { _, p in
                                Text(p).font(Fonts.fraunces(17 * s.scale, weight: .regular)).lineSpacing(12 * s.scale).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 20).padding(.bottom, 16 * s.scale)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer().frame(height: 20)
                                Text(s.isDone ? "Capítulo completado · Toca para deshacer" : "Marcar como completado")
                                    .font(Fonts.inter(14, weight: .semibold)).foregroundStyle(s.isDone ? Tokens.forest : Tokens.cream)
                                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(s.isDone ? Tokens.sageA(0.12) : accent))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(s.isDone ? Tokens.sageA(0.3) : accent, lineWidth: 1))
                                    .pressable(scale: 0.98, tag: "chapter-done") { model.toggleDone() }
                                Spacer().frame(height: 36)
                                Hairline(alpha: 0.18)
                                Spacer().frame(height: 22)
                                HStack {
                                    if cur.number > 1 { LessonPagerPill(label: "← Cap. \(cur.number - 1)") { model.prev() } } else { Spacer().frame(width: 1) }
                                    Spacer()
                                    Text("\(cur.number) / \(s.total)").font(Fonts.fraunces(13, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
                                    Spacer()
                                    if cur.number < s.total { LessonPagerPill(label: "Cap. \(cur.number + 1) →") { model.next() } } else { Spacer().frame(width: 1) }
                                }
                                Spacer().frame(height: 60)
                            }
                            .padding(.horizontal, 20)
                            SiteFooter()
                        }
                    }
                    .uiId("egw-reader")
                    .onChange(of: s.chapter) { _ in proxy.scrollTo("egw-top", anchor: .top) }
                }
            }
            .sheet(isPresented: $toc) { tocView(s, meta: meta, book: book, accent: accent).presentationDetents([.large]).presentationDragIndicator(.visible) }
            .sheet(isPresented: Binding(get: { drawer != nil }, set: { if !$0 { drawer = nil } })) {
                drawerView(s, cur: cur, accent: accent).presentationDetents([.large]).presentationDragIndicator(.visible)
            }
        } else {
            Color.clear
        }
    }

    private func tocView(_ s: BookUi, meta: EgwBookMeta, book: EgwBook, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLine("— Curso · \(s.total) capítulos", color: Tokens.sage, size: 10.5)
            Spacer().frame(height: 6)
            Text(meta.title).font(Fonts.fraunces(22, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
            Text(meta.subtitle).font(Fonts.fraunces(13, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
            Spacer().frame(height: 10)
            GeometryReader { geo in
                ZStack(alignment: .leading) { Capsule().fill(Tokens.sageA(0.14)); Capsule().fill(accent).frame(width: geo.size.width * CGFloat(s.pct) / 100) }
            }
            .frame(height: 4)
            Spacer().frame(height: 6)
            Text("\(s.completedCount) / \(s.total) completados · \(s.pct)%").font(Fonts.inter(12)).foregroundStyle(Tokens.sageText)
            Spacer().frame(height: 12)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(book.chapters, id: \.number) { c in
                        let isCur = c.number == s.chapter
                        let done = s.done.contains(c.number)
                        HStack(spacing: 12) {
                            if done { IconView(name: "ic_check", color: Tokens.sage).frame(width: 16, height: 16).frame(width: 30, alignment: .leading) }
                            else { Text(String(format: "%02d", c.number)).font(Fonts.fraunces(13, weight: .bold, italic: true)).foregroundStyle(Tokens.sageText).frame(width: 30, alignment: .leading) }
                            Text(c.title).font(Fonts.fraunces(15, weight: isCur ? .semibold : .medium)).foregroundStyle(done && !isCur ? Tokens.sageText : Tokens.ink)
                            Spacer(minLength: 0)
                            if s.hasNotes.contains(c.number) { IconView(name: "ic_note", color: Tokens.sage).frame(width: 12, height: 12) }
                            if s.bookmarks.contains(where: { $0.slug == slug && $0.chapter == c.number }) { IconView(name: "ic_bookmark", color: Tokens.sage).frame(width: 12, height: 12) }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(isCur ? Tokens.sageA(0.12) : Color.clear))
                        .pressable(scale: 0.99, tag: "chapter-\(c.number)") { toc = false; model.open(c.number) }
                    }
                }
            }
            Text("Volver al catálogo").font(Fonts.inter(13, weight: .semibold)).foregroundStyle(Tokens.sage).padding(.top, 10).pressable(scale: 0.98) { toc = false; router.go(.egw) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 24)
        .background(Tokens.cream.ignoresSafeArea())
        .uiId("egw-toc")
    }

    @ViewBuilder
    private func drawerView(_ s: BookUi, cur: EgwChapter, accent: Color) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([("notes", "Notas"), ("bookmarks", "Marcadores"), ("progress", "Progreso")], id: \.0) { id, label in
                        let active = drawer == id
                        Text(label + (id == "bookmarks" && !s.bookmarks.isEmpty ? " \(s.bookmarks.count)" : ""))
                            .font(Fonts.inter(13, weight: .semibold)).foregroundStyle(active ? Tokens.cream : Tokens.forest)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(active ? Tokens.forest : Tokens.sageA(0.08)))
                            .pressable(scale: 0.97, tag: "egw-tab-\(id)") { drawer = id }
                    }
                }
                Spacer().frame(height: 20)
                switch drawer {
                case "notes":
                    EyebrowLine("— Notas · Capítulo \(cur.number)", color: Tokens.sage, size: 10.5)
                    Spacer().frame(height: 6)
                    Text(cur.title).font(Fonts.fraunces(20, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                    Spacer().frame(height: 4)
                    Text(s.savedAt.map { "Guardado \(relativeTimeEs($0))" } ?? (s.notes.isEmpty ? "Empieza a escribir — guardamos automáticamente" : "Tus apuntes anteriores")).font(Fonts.inter(12)).foregroundStyle(Tokens.sageText)
                    Spacer().frame(height: 12)
                    ZStack(alignment: .topLeading) {
                        if s.notes.isEmpty { Text("Escribe lo que te habló de este capítulo…").font(Fonts.inter(14)).foregroundStyle(Color(hex: 0x9AA792)).padding(.top, 8).padding(.leading, 5) }
                        TextEditor(text: Binding(get: { model.state.notes }, set: { model.notes($0) }))
                            .font(Fonts.inter(14.5)).foregroundStyle(Tokens.ink).tint(Tokens.sage).scrollContentBackground(.hidden).frame(height: 180)
                            .uiId("notes-area")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.sageA(0.2), lineWidth: 1))
                    if !s.notes.isEmpty { Text("Borrar nota").font(Fonts.inter(11, weight: .semibold)).foregroundStyle(Color(hex: 0x8A3A2A)).padding(.top, 8).pressable(scale: 0.97) { model.clearNotes() } }
                case "bookmarks":
                    if s.bookmarks.isEmpty { Text("Aún no hay marcadores. Toca el marcador de la barra para guardar un capítulo.").font(Fonts.inter(14)).lineSpacing(5).foregroundStyle(Tokens.sageText) }
                    ForEach(s.bookmarks) { bm in
                        HStack(spacing: 12) {
                            Text(bm.bookId).font(Fonts.inter(10, weight: .bold)).tracking(0.8).foregroundStyle(Tokens.sage).frame(width: 40, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cap. \(bm.chapter) · \(bm.chapterTitle)").font(Fonts.fraunces(15, weight: .medium)).foregroundStyle(Tokens.ink)
                                Text("\(bm.bookTitle) · \(relativeTimeEs(bm.addedAt))").font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .pressable(scale: 0.98) { drawer = nil; if bm.slug == slug { model.open(bm.chapter) } else { router.go(.egwBook(slug: bm.slug, chapter: bm.chapter)) } }
                            IconView(name: "ic_nav_close", color: Tokens.sageText).frame(width: 16, height: 16).pressable { model.removeBookmark(bm.slug, bm.chapter) }.accessibilityLabel("Quitar marcador")
                        }
                        .padding(.vertical, 10)
                        Hairline(alpha: 0.12)
                    }
                case "progress":
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(s.pct)).font(Fonts.fraunces(40, weight: .bold, italic: true)).foregroundStyle(accent)
                        Text("%").font(Fonts.fraunces(18)).foregroundStyle(Tokens.sage)
                        Spacer().frame(width: 10)
                        Text("\(s.completedCount) de \(s.total) capítulos").font(Fonts.inter(13)).foregroundStyle(Tokens.sageText)
                    }
                    Spacer().frame(height: 14)
                    Text("Reiniciar progreso del libro").font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Color(hex: 0x8A3A2A)).pressable(scale: 0.97) { model.resetProgress() }
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 28)
        }
        .background(Tokens.cream.ignoresSafeArea())
        .uiId("egw-drawer")
    }
}
