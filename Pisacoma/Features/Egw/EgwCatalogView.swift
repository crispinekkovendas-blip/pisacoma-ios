import SwiftUI

/// `#RRGGBB` → Color, sage when unparsable.
func hexColor(_ s: String) -> Color {
    var h = s.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else { return Tokens.sage }
    return Color(hex: v)
}

/// The site's /egw: hero with the library numbers, then four «pasillos», each a horizontal rail of covers with reading progress.
struct EgwCatalogView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var model: EgwCatalogModel

    init() { _model = StateObject(wrappedValue: EgwCatalogModel(app: AppModel.shared)) }

    var body: some View {
        let s = model.state
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 44)
                    EyebrowLine("— Biblioteca de pioneros · Don de profecía")
                    Spacer().frame(height: 18)
                    PageTitle(titleWithEm("Veinticinco libros,", "cuatro pasillos", tail: "."))
                    Spacer().frame(height: 22)
                    Lede("Un curso por volumen, organizados como una pequeña biblioteca: cada pasillo agrupa los libros por su intención original — clásicos pioneros, devocionales, vida práctica, y los tiempos finales.")
                    Spacer().frame(height: 26)
                    FlowLayout(spacing: 18) {
                        Meta(num: String(s.books.count), label: "volúmenes")
                        Rectangle().fill(Tokens.sageA(0.2)).frame(width: 1, height: 28)
                        Meta(num: Self.thousands(s.totalChapters), label: "capítulos")
                        Rectangle().fill(Tokens.sageA(0.2)).frame(width: 1, height: 28)
                        Meta(num: String(s.totalDone), label: "leídos")
                        if s.totalDone > 0 {
                            Rectangle().fill(Tokens.sageA(0.2)).frame(width: 1, height: 28)
                            Meta(num: "\(s.overallPct)%", label: "avance global", small: true)
                        }
                    }
                    Spacer().frame(height: 36)
                }
                .padding(.horizontal, 20)
                ForEach(s.rails) { rail in
                    let aisle = rail.aisle
                    let books = rail.books
                    let aisleCh = books.reduce(0) { $0 + $1.chapters }
                    let aisleDone = books.reduce(0) { $0 + (s.stats[$1.slug]?.done ?? 0) }
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 14) {
                            Text(aisle.roman).font(Fonts.fraunces(40, weight: .bold, italic: true)).foregroundStyle(Color(hex: 0xA78447, alpha: 0.25))
                            VStack(alignment: .leading, spacing: 0) {
                                EyebrowLine("— Pasillo \(aisle.roman)", color: Tokens.sage, size: 10.5)
                                Spacer().frame(height: 6)
                                Text(aisle.label).font(Fonts.fraunces(24, weight: .regular, italic: true)).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true)
                                Spacer().frame(height: 4)
                                Text(aisle.lede).font(Fonts.inter(13)).lineSpacing(4).foregroundStyle(Tokens.sageText).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(String(books.count)).font(Fonts.fraunces(18, weight: .bold, italic: true)).foregroundStyle(Tokens.inkDeep)
                                EyebrowLine("volúmenes", color: Tokens.sageText, size: 9.5, tracking: 1.4)
                                if aisleDone > 0 {
                                    Text("\(Int((Double(aisleDone) * 100 / Double(max(1, aisleCh))).rounded()))%").font(Fonts.fraunces(18, weight: .bold, italic: true)).foregroundStyle(Tokens.sage)
                                    EyebrowLine("avance", color: Tokens.sageText, size: 9.5, tracking: 1.4)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        Spacer().frame(height: 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(books) { b in
                                    Cover(book: b, stats: s.stats[b.slug] ?? BookStats(done: 0, lastCh: nil)) { ch in router.go(.egwBook(slug: b.slug, chapter: ch)) }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .uiId("rail-row-\(aisle.roman)")
                        Spacer().frame(height: 40)
                    }
                    .uiId("rail-\(aisle.roman)")
                }
                SiteFooter()
            }
        }
        .uiId("egw-page")
        .onAppear { model.refresh() }
    }

    static func thousands(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.locale = Locale(identifier: "es_PE")
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}

private struct Meta: View {
    let num: String
    let label: String
    var small = false
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(num).font(Fonts.fraunces(small ? 16 : 25.6, weight: .bold, italic: true)).foregroundStyle(Tokens.inkDeep).fixedSize()
            EyebrowLine(label, color: Tokens.sageText, size: 11, tracking: 1.6).fixedSize()
        }
    }
}

/// `.card`: a 2:3 poster with the book's colour behind it, the badge for featured books, the progress bar, title and chapter count.
private struct Cover: View {
    let book: EgwBookMeta
    let stats: BookStats
    let onOpen: (Int?) -> Void

    private var coverUrl: URL { Bundle.main.resourceURL!.appendingPathComponent("Content/covers/\(book.cover)") }

    var body: some View {
        let accent = hexColor(book.color)
        let pct = book.chapters == 0 ? 0 : Int((Double(stats.done) * 100 / Double(book.chapters)).rounded())
        let isDone = book.chapters > 0 && stats.done == book.chapters
        let continueAt = stats.lastCh ?? 1
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                accent
                if let ui = UIImage(contentsOfFile: coverUrl.path) {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 132, height: 198).clipped().accessibilityLabel("Portada de \(book.title)")
                }
                LinearGradient(stops: [.init(color: .clear, location: 0.55), .init(color: Color.black.opacity(0.4), location: 1)], startPoint: .top, endPoint: .bottom)
                if egwFeatured.contains(book.slug) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0xE8D091)).frame(width: 5, height: 5)
                        Text(isDone ? "completado" : (stats.hasProgress ? "en curso" : "destacado")).font(Fonts.inter(8.5, weight: .bold)).tracking(1).foregroundStyle(Tokens.cream)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: 0x16241A, alpha: 0.8)))
                    .padding(8)
                }
                if stats.hasProgress {
                    VStack(alignment: .leading, spacing: 5) {
                        Spacer()
                        Text(isDone ? "Releer" : "Continuar · cap. \(continueAt)").font(Fonts.inter(10, weight: .semibold)).foregroundStyle(Tokens.cream).accessibilityIdentifier("continue-\(book.slug)")
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.33))
                                Capsule().fill(Color(hex: 0xE8D091)).frame(width: geo.size.width * CGFloat(pct) / 100)
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(8)
                }
            }
            .frame(width: 132, height: 198)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Spacer().frame(height: 10)
            Text(book.title).font(Fonts.fraunces(13.5, weight: .medium)).foregroundStyle(Tokens.inkDeep).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 4)
            HStack(spacing: 5) {
                Text(book.id).font(Fonts.inter(9.5, weight: .bold)).tracking(0.8).foregroundStyle(accent)
                Text("·").foregroundStyle(Tokens.sageText)
                Text(stats.hasProgress ? "\(stats.done)/\(book.chapters) cap." : "\(book.chapters) cap.").font(Fonts.inter(10.5)).foregroundStyle(Tokens.sageText)
                if stats.hasProgress { Text("\(pct)%").font(Fonts.inter(10.5, weight: .semibold)).foregroundStyle(Tokens.sage) }
            }
        }
        .frame(width: 132, alignment: .leading)
        .pressable(scale: 0.97, tag: "cover-\(book.slug)") { onOpen(stats.hasProgress ? continueAt : nil) }
    }
}
