import SwiftUI

/// The site's /escuela-sabatica/<n>: sticky toolbar, crumbs + title, 7 day tabs, the day's text, done CTA, pager, drawer, verse popup.
struct LessonView: View {
    let number: Int
    let day: Int?
    @EnvironmentObject private var router: Router
    @StateObject private var model: LessonModel
    @State private var drawer: String? = nil // "notes" | "bookmarks" | "progress"
    @State private var ref: RefSelection? = nil

    struct RefSelection: Identifiable { let key: String; let display: String; var id: String { key } }

    init(number: Int, day: Int?) {
        self.number = number
        self.day = day
        _model = StateObject(wrappedValue: LessonModel(app: AppModel.shared, number: number, initialDay: day))
    }

    var body: some View {
        let s = model.state
        if s.notFound {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lección no encontrada").font(Fonts.fraunces(24)).foregroundStyle(Tokens.inkDeep)
                Text("← Volver").font(Fonts.inter(15)).foregroundStyle(Tokens.sage).pressable { router.go(.escuela) }
                Spacer()
            }
            .padding(20)
        } else if let q = s.quarterly, let lesson = s.lesson, s.days.indices.contains(s.activeDay) {
            let current = s.days[s.activeDay]
            VStack(spacing: 0) {
                toolbar(s, lesson: lesson)
                Hairline(alpha: 0.12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 10) {
                                Text("ESCUELA SABÁTICA").font(Fonts.inter(11, weight: .semibold)).tracking(2.2).foregroundStyle(Tokens.sage).pressable(scale: 0.98) { router.go(.escuela) }
                                Text("/").font(Fonts.inter(11)).foregroundStyle(Tokens.sageText.opacity(0.5))
                                Text("LECCIÓN \(lesson.number)").font(Fonts.inter(11, weight: .semibold)).tracking(2.2).foregroundStyle(Tokens.sageText)
                            }
                            .padding(.top, 22).padding(.bottom, 18)
                            EyebrowLine("\(lesson.startDate) — \(lesson.endDate)", color: Tokens.sageText, size: 11, tracking: 1.8)
                            Spacer().frame(height: 10)
                            Text("Lección \(lesson.number): \(lesson.title)").font(Fonts.fraunces(26, weight: .semibold)).tracking(-0.022 * 26).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true)
                            Spacer().frame(height: 6)
                            Text(q.title).font(Fonts.fraunces(15, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
                            Spacer().frame(height: 22)
                        }
                        .padding(.horizontal, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(s.days.enumerated()), id: \.offset) { i, d in
                                    DayTab(index: i, title: d.title.isEmpty ? dayLabels[i] : d.title, active: i == s.activeDay, done: s.doneDays.contains(i), hasNotes: s.daysWithNotes.contains(i)) { model.selectDay(i) }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        Spacer().frame(height: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(current.title.isEmpty ? dayLabels[s.activeDay] : current.title).font(Fonts.fraunces(22, weight: .semibold)).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true)
                            Spacer().frame(height: 8)
                            EyebrowLine(dayLabels[s.activeDay], color: Tokens.sageText, size: 10.5)
                            Spacer().frame(height: 16)
                            MarkdownText(blocks: current.blocks, scale: s.scale) { key in ref = RefSelection(key: key, display: Self.displayFor(key, current)) }
                            Spacer().frame(height: 30)
                            Text(s.isDone ? "Día completado · toca para deshacer" : "Marcar día como completado")
                                .font(Fonts.inter(14, weight: .semibold)).foregroundStyle(s.isDone ? Tokens.forest : Tokens.cream)
                                .frame(maxWidth: .infinity).padding(.vertical, 15)
                                .background(RoundedRectangle(cornerRadius: 14).fill(s.isDone ? Tokens.sageA(0.12) : Tokens.forest))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(s.isDone ? Tokens.sageA(0.3) : Tokens.forest, lineWidth: 1))
                                .pressable(scale: 0.98, tag: "day-mark-cta") { model.toggleDone() }
                            Spacer().frame(height: 14)
                            if s.activeDay < s.totalDays - 1 {
                                HStack(spacing: 6) {
                                    Text("Siguiente:").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText)
                                    Text(dayLabels[s.activeDay + 1]).font(Fonts.fraunces(15, weight: .regular, italic: true)).foregroundStyle(Tokens.forest)
                                    Text("→").font(Fonts.inter(14)).foregroundStyle(Tokens.sage)
                                }
                                .padding(.vertical, 4)
                                .pressable(scale: 0.98, tag: "next-day") { model.selectDay(s.activeDay + 1) }
                            } else if lesson.number < q.lessons.count {
                                HStack(spacing: 6) {
                                    Text("¡Felicidades! Has terminado la lección ·").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText)
                                    Text("Lección \(lesson.number + 1) →").font(Fonts.fraunces(15, weight: .regular, italic: true)).foregroundStyle(Tokens.forest)
                                }
                                .padding(.vertical, 4)
                                .pressable(scale: 0.98) { router.go(.leccion(number: lesson.number + 1, day: nil)) }
                            } else {
                                Text("¡Felicidades! Has terminado el trimestre.").font(Fonts.inter(14)).foregroundStyle(Tokens.sageText)
                            }
                            Spacer().frame(height: 14)
                            HStack(spacing: 10) {
                                ShareButton(
                                    title: "Lección \(lesson.number) · \(dayLabels[s.activeDay])",
                                    text: "Escuela Sabática · Lección \(lesson.number): \(lesson.title) · \(dayLabels[s.activeDay])" + (s.activeDay > 0 && !current.title.isEmpty ? ": \(current.title)" : ""),
                                    path: "/escuela-sabatica/\(lesson.number)/?dia=\(s.activeDay)",
                                    label: "Compartir este día"
                                )
                                if let slug = s.quizSlug {
                                    Text("Quiz de la lección").font(Fonts.inter(14.4, weight: .medium)).foregroundStyle(Tokens.cream)
                                        .padding(.horizontal, 16).padding(.vertical, 9).background(Capsule().fill(Tokens.forest))
                                        .pressable(scale: 0.97, tag: "lesson-quiz") { router.go(.quizPack(slug: slug)) }
                                }
                            }
                            Spacer().frame(height: 40)
                            Hairline(alpha: 0.18)
                            Spacer().frame(height: 22)
                            HStack(spacing: 10) {
                                Spacer(minLength: 0)
                                if lesson.number > 1 { LessonPagerPill(label: "← Lección \(lesson.number - 1)") { router.go(.leccion(number: lesson.number - 1, day: nil)) } }
                                LessonPagerPill(label: "Todas las lecciones", ochre: true) { router.go(.escuela) }
                                if lesson.number < q.lessons.count { LessonPagerPill(label: "Lección \(lesson.number + 1) →") { router.go(.leccion(number: lesson.number + 1, day: nil)) } }
                                Spacer(minLength: 0)
                            }
                            Spacer().frame(height: 60)
                        }
                        .padding(.horizontal, 20)
                    }
                    SiteFooter()
                }
            }
            .uiId("lesson-page")
            .sheet(isPresented: Binding(get: { drawer != nil }, set: { if !$0 { drawer = nil } })) {
                drawerView(s, q: q, lesson: lesson, current: current)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $ref) { r in
                BibleRefSheet(refKey: r.key, display: r.display)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        } else {
            Color.clear
        }
    }

    private func toolbar(_ s: LessonUi, lesson: Lesson) -> some View {
        HStack(spacing: 5) {
            IconView(name: "ic_back", color: Tokens.sage).frame(width: 14, height: 14).frame(width: 32, height: 32)
                .pressable(scale: 0.97, tag: "lesson-back") { router.go(.escuela) }
                .accessibilityLabel("Volver a las lecciones")
            VStack(alignment: .leading, spacing: 4) {
                Text("Lec. \(lesson.number) · Día \(s.activeDay + 1)").font(Fonts.fraunces(12.5, weight: .bold, italic: true)).foregroundStyle(Tokens.forest).lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tokens.sageA(0.14))
                        Capsule().fill(Tokens.sage).frame(width: geo.size.width * CGFloat(s.pct) / 100)
                    }
                }
                .frame(height: 3)
            }
            ToolbarIcon(icon: "ic_check", label: s.isDone ? "Marcar día como no leído" : "Marcar día como completado", active: s.isDone, tag: "day-done") { model.toggleDone() }
            ToolbarIcon(icon: "ic_bookmark", label: s.isBookmarked ? "Quitar marcador" : "Agregar marcador", active: s.isBookmarked, tag: "lesson-bookmark") { model.toggleBookmark() }
            TextSizeControls(onSmaller: { model.smaller() }, onLarger: { model.larger() })
            ToolbarIcon(icon: "ic_note", label: "Notas, marcadores y progreso", active: drawer != nil, tag: "lesson-notes") { drawer = "notes" }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color(hex: 0xF7F4E6, alpha: 0.95))
    }

    @ViewBuilder
    private func drawerView(_ s: LessonUi, q: Quarterly, lesson: Lesson, current: DayView) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([("notes", "Notas"), ("bookmarks", "Marcadores"), ("progress", "Progreso")], id: \.0) { id, label in
                        let active = drawer == id
                        HStack(spacing: 6) {
                            Text(label).font(Fonts.inter(13, weight: .semibold)).foregroundStyle(active ? Tokens.cream : Tokens.forest)
                            if id == "bookmarks" && !s.bookmarks.isEmpty { Text(String(s.bookmarks.count)).font(Fonts.inter(11)).foregroundStyle(active ? Tokens.cream : Tokens.sage) }
                            if id == "notes" && s.daysWithNotes.contains(s.activeDay) { Circle().fill(active ? Tokens.cream : Tokens.sage).frame(width: 6, height: 6) }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(active ? Tokens.forest : Tokens.sageA(0.08)))
                        .pressable(scale: 0.97, tag: "drawer-tab-\(id)") { drawer = id }
                    }
                }
                Spacer().frame(height: 20)
                switch drawer {
                case "notes":
                    EyebrowLine("— Notas del día \(s.activeDay + 1)", color: Tokens.sage, size: 10.5)
                    Spacer().frame(height: 6)
                    Text(current.title.isEmpty ? dayLabels[s.activeDay] : current.title).font(Fonts.fraunces(20, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                    Spacer().frame(height: 4)
                    Text(s.savedAt.map { "Guardado \(relativeTimeEs($0))" } ?? (s.notes.isEmpty ? "Empieza a escribir — guardamos automáticamente" : "Tus apuntes anteriores"))
                        .font(Fonts.inter(12)).foregroundStyle(Tokens.sageText)
                    Spacer().frame(height: 12)
                    ZStack(alignment: .topLeading) {
                        if s.notes.isEmpty {
                            Text("Escribe lo que aprendiste, citas favoritas, preguntas para el sábado, aplicaciones personales…").font(Fonts.inter(14)).foregroundStyle(Color(hex: 0x9AA792)).padding(.top, 8).padding(.leading, 5)
                        }
                        TextEditor(text: Binding(get: { model.state.notes }, set: { model.notes($0) }))
                            .font(Fonts.inter(14.5)).foregroundStyle(Tokens.ink).tint(Tokens.sage)
                            .scrollContentBackground(.hidden)
                            .frame(height: 180)
                            .uiId("notes-area")
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.7)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.sageA(0.2), lineWidth: 1))
                    Spacer().frame(height: 8)
                    HStack {
                        Text("\(s.notes.count) caracteres · \(s.notes.split(whereSeparator: { $0.isWhitespace }).count) palabras").font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                        Spacer()
                        if !s.notes.isEmpty { Text("Borrar nota").font(Fonts.inter(11, weight: .semibold)).foregroundStyle(Color(hex: 0x8A3A2A)).pressable(scale: 0.97) { model.clearNotes() } }
                    }
                case "bookmarks":
                    if s.bookmarks.isEmpty {
                        Text("Aún no hay marcadores").font(Fonts.fraunces(18, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                        Text("Toca el botón de marcador en la barra superior para guardar lecciones importantes del trimestre.").font(Fonts.inter(14)).lineSpacing(5).foregroundStyle(Tokens.sageText).padding(.top, 6)
                    } else {
                        ForEach(s.bookmarks) { bm in
                            HStack(spacing: 12) {
                                Text("Lec. \(bm.leccionN)").font(Fonts.fraunces(13, weight: .bold, italic: true)).foregroundStyle(Tokens.forest).frame(width: 52, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bm.title).font(Fonts.fraunces(15, weight: .medium)).foregroundStyle(Tokens.ink)
                                    Text(relativeTimeEs(bm.addedAt)).font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .pressable(scale: 0.98) { drawer = nil; router.go(.leccion(number: bm.leccionN, day: nil)) }
                                IconView(name: "ic_nav_close", color: Tokens.sageText).frame(width: 16, height: 16).pressable { model.removeBookmark(bm.leccionN) }.accessibilityLabel("Quitar marcador")
                            }
                            .padding(.vertical, 10)
                            Hairline(alpha: 0.12)
                        }
                    }
                case "progress":
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(s.pct)).font(Fonts.fraunces(40, weight: .bold, italic: true)).foregroundStyle(Tokens.forest)
                        Text("%").font(Fonts.fraunces(18)).foregroundStyle(Tokens.sage)
                        Spacer().frame(width: 10)
                        Text("\(s.completedCount) de \(s.totalDays) días").font(Fonts.inter(13)).foregroundStyle(Tokens.sageText)
                    }
                    Spacer().frame(height: 10)
                    HStack(spacing: 22) {
                        Stat(n: s.completedCount, label: "completados"); Stat(n: s.daysWithNotes.count, label: "con notas"); Stat(n: s.totalDays - s.completedCount, label: "restantes")
                    }
                    Spacer().frame(height: 18)
                    HStack { EyebrowLine("Lecciones del trimestre", color: Tokens.sageText, size: 10.5); Spacer(); Text(String(q.lessons.count)).font(Fonts.inter(11)).foregroundStyle(Tokens.sageText) }
                    Spacer().frame(height: 8)
                    ForEach(q.lessons) { l in
                        let done = s.progress[l.number] ?? 0
                        let isCur = l.number == lesson.number
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", l.number)).font(Fonts.fraunces(14, weight: .bold, italic: true)).foregroundStyle(isCur ? Tokens.forest : Tokens.sageText).frame(width: 26, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(l.title).font(Fonts.fraunces(14, weight: isCur ? .semibold : .medium)).foregroundStyle(Tokens.ink).lineLimit(1)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Tokens.sageA(0.14))
                                        Capsule().fill(Tokens.sage).frame(width: geo.size.width * CGFloat(done) / CGFloat(max(1, l.days.count)))
                                    }
                                }
                                .frame(height: 3)
                            }
                            Text("\(done)/\(l.days.count)").font(Fonts.inter(11)).foregroundStyle(Tokens.sageText)
                        }
                        .padding(.vertical, 8)
                        .pressable(scale: 0.98) { drawer = nil; router.go(.leccion(number: l.number, day: nil)) }
                    }
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 28)
        }
        .background(Tokens.cream.ignoresSafeArea())
        .uiId("lesson-drawer")
    }

    /// The text the reference was written as (for the popup title), found back in the day's blocks.
    static func displayFor(_ key: String, _ day: DayView) -> String {
        for b in day.blocks {
            let t: Inline?
            switch b {
            case let .paragraph(x), let .prompt(x), let .bullet(x): t = x
            case let .quote(_, x): t = x
            default: t = nil
            }
            guard let t, let r = t.refs.first(where: { $0.key == key }) else { continue }
            return (t.text as NSString).substring(with: NSRange(location: r.start, length: r.end - r.start))
        }
        return key
    }
}

private struct DayTab: View {
    let index: Int
    let title: String
    let active: Bool
    let done: Bool
    let hasNotes: Bool
    let onClick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(dayShort[index].uppercased()).font(Fonts.inter(10, weight: .bold)).tracking(1.6).foregroundStyle(active ? Tokens.cream.opacity(0.8) : Tokens.sage)
                if done { IconView(name: "ic_check", color: active ? Tokens.cream : Tokens.sage).frame(width: 10, height: 10) }
                if hasNotes { IconView(name: "ic_note", color: active ? Tokens.cream : Tokens.sage).frame(width: 10, height: 10) }
            }
            Text(title).font(Fonts.fraunces(12.5, weight: .medium)).foregroundStyle(active ? Tokens.cream : Tokens.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 104 - 24, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(active ? Tokens.forest : (done ? Tokens.sageA(0.12) : Color.white.opacity(0.55))))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Tokens.forest : Tokens.sageA(0.18), lineWidth: 1))
        .pressable(scale: 0.97, tag: active ? "day-tab-\(index)-selected" : "day-tab-\(index)", action: onClick)
    }
}

private struct Stat: View {
    let n: Int
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(n)).font(Fonts.fraunces(20, weight: .bold, italic: true)).foregroundStyle(Tokens.inkDeep)
            EyebrowLine(label, color: Tokens.sageText, size: 10, tracking: 1.4)
        }
    }
}

struct LessonPagerPill: View {
    let label: String
    var ochre = false
    let action: () -> Void
    var body: some View {
        Text(label).font(Fonts.inter(13, weight: .semibold)).foregroundStyle(ochre ? Ochre.label : Tokens.forest)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(Capsule().fill(Color.white.opacity(0.5)))
            .overlay(Capsule().stroke(ochre ? Color(hex: 0xB8924F, alpha: 0.4) : Tokens.sageA(0.24), lineWidth: 1))
            .pressable(scale: 0.97, action: action)
    }
}
