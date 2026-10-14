import SwiftUI

/// The site's /escuela-sabatica: hero with meta + progress, «Nuevo trimestre» when ended, the week's lesson card, all 13 lessons.
struct QuarterView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var model: QuarterModel

    init() { _model = StateObject(wrappedValue: QuarterModel(app: AppModel.shared)) }

    var body: some View {
        let s = model.state
        ScrollView {
            if let q = s.quarterly, !q.lessons.isEmpty {
                let cur = q.lessons[min(s.currentIdx, q.lessons.count - 1)]
                let accent = lessonAccents[s.currentIdx % lessonAccents.count]
                let words = q.title.split(separator: " ").map(String.init)
                LazyVStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 44)
                        EyebrowLine("— Escuela Sabática · \(q.humanDate ?? "")")
                        Spacer().frame(height: 18)
                        PageTitle(titleWithEm(words.prefix(2).joined(separator: " "), words.dropFirst(2).joined(separator: " ")))
                        Spacer().frame(height: 22)
                        Lede(String((q.description ?? "").prefix(240)) + "…")
                        Spacer().frame(height: 28)
                        DashedRule()
                        FlowLayout(spacing: 18) {
                            MetaItem(num: String(q.lessons.count), label: "lecciones")
                            MetaSep()
                            MetaItem(num: String(q.lessons.count * 7), label: "días")
                            MetaSep()
                            MetaItem(num: q.startDate, label: "— \(q.endDate)", small: true)
                        }
                        .padding(.vertical, 18)
                        DashedRule()
                        Spacer().frame(height: 24)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Tokens.sageA(0.14))
                                Capsule().fill(accent).frame(width: geo.size.width * CGFloat(s.currentIdx + 1) / CGFloat(q.lessons.count))
                            }
                        }
                        .frame(height: 4)
                        Spacer().frame(height: 12)
                        EyebrowLine(s.ended ? "Trimestre completado · \(q.lessons.count) lecciones" : "Vamos por la lección \(s.currentIdx + 1) de \(q.lessons.count)", color: Color(hex: 0x57654A), size: 11.5, tracking: 1.6)
                        if s.ended {
                            Spacer().frame(height: 34)
                            VStack(alignment: .leading, spacing: 0) {
                                EyebrowLine("— Nuevo trimestre", color: Color(hex: 0x8A6A32), size: 11, tracking: 2.2)
                                Spacer().frame(height: 8)
                                PageTitle(titleWithEm("Empieza el", s.nextStartLabel, size: 24), size: 24)
                                Spacer().frame(height: 6)
                                Text("Las lecciones aparecerán aquí en cuanto se publiquen. Mientras tanto, puedes repasar las \(q.lessons.count) lecciones de «\(q.title)».")
                                    .font(Fonts.inter(15)).lineSpacing(5).foregroundStyle(Tokens.ledeInk).fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.vertical, 22)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0xFBF9EF, alpha: 0.7)))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xB8924F, alpha: 0.5), lineWidth: 1))
                        }
                        Spacer().frame(height: 38)
                        EyebrowLine(s.ended ? "— Última lección del trimestre" : "— Lección de esta semana", color: Ochre.label)
                        Spacer().frame(height: 14)
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .lastTextBaseline, spacing: 14) {
                                EyebrowLine("Lec.", color: Tokens.sageText, size: 10, tracking: 2)
                                Text(String(cur.number)).font(Fonts.fraunces(51, weight: .bold, italic: true)).tracking(-0.04 * 51).foregroundStyle(accent)
                            }
                            DashedRule()
                            VStack(alignment: .leading, spacing: 6) {
                                Text(cur.title).font(Fonts.fraunces(24, weight: .semibold)).tracking(-0.022 * 24).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true)
                                EyebrowLine("\(cur.startDate) — \(cur.endDate) · 7 días de estudio", color: Tokens.sageText, size: 11, tracking: 1.8)
                                HStack(spacing: 8) {
                                    Text("Empezar a estudiar").font(Fonts.inter(13, weight: .semibold)).foregroundStyle(accent)
                                    IconView(name: "ic_nav_arrow", color: accent).frame(width: 16, height: 16)
                                }
                                .padding(.top, 8)
                                Rectangle().fill(accent).frame(width: 150, height: 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24).padding(.vertical, 26)
                        .background(RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(hex: 0xFBF9EF), Color(hex: 0xECE9D6)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Tokens.sageA(0.20), lineWidth: 1))
                        .pressable(scale: 0.99, tag: "current-lesson") { router.go(.leccion(number: cur.number, day: nil)) }
                        Spacer().frame(height: 50)
                        EyebrowLine("— Todas las lecciones del trimestre")
                        Spacer().frame(height: 18)
                    }
                    .padding(.horizontal, 20)
                    ForEach(Array(q.lessons.enumerated()), id: \.element.number) { i, l in
                        let c = lessonAccents[i % lessonAccents.count]
                        let isCur = i == s.currentIdx
                        let isPast = i < s.currentIdx
                        let done = s.progress[l.number] ?? 0
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(isCur ? c : (isPast ? Color(hex: 0x6B7D5B, alpha: 0.12) : Tokens.sageA(0.10)))
                                Text(String(format: "%02d", l.number)).font(Fonts.fraunces(22.4, weight: .bold, italic: true)).tracking(-0.03 * 22.4).foregroundStyle(isCur ? Tokens.cream : (isPast ? Tokens.sageText : c))
                            }
                            .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                EyebrowLine(l.startDate, color: Tokens.sageText, size: 10.5, tracking: 1.8)
                                Text(l.title).font(Fonts.fraunces(16, weight: isCur ? .semibold : .medium)).foregroundStyle(isCur ? Tokens.inkDeep : Tokens.ink).fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 4) {
                                    ForEach(0..<l.days.count, id: \.self) { d in
                                        Circle().fill(d < done ? c : Tokens.sageA(0.18)).frame(width: 6, height: 6)
                                            .uiId(d < done ? "lesson-\(l.number)-dots-done-\(d + 1)" : "lesson-\(l.number)-dot-\(d)")
                                    }
                                }
                                .padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                            if isCur { Text("→").font(Fonts.inter(16)).foregroundStyle(c) }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.55)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Tokens.sageA(0.16), lineWidth: 1))
                        .pressable(scale: 0.99, tag: "lesson-\(l.number)") { router.go(.leccion(number: l.number, day: nil)) }
                        .padding(.horizontal, 20).padding(.bottom, 12)
                    }
                    Spacer().frame(height: 40)
                    SiteFooter()
                }
            }
        }
        .uiId("lesson-list")
        .onAppear { model.refresh() }
    }
}

private struct MetaItem: View {
    let num: String
    let label: String
    var small = false
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(num).font(Fonts.fraunces(small ? 16 : 25.6, weight: .bold, italic: !small)).tracking(-0.3).foregroundStyle(Tokens.inkDeep).fixedSize()
            EyebrowLine(label, color: Tokens.sageText, size: 11, tracking: 1.6).fixedSize()
        }
    }
}

private struct MetaSep: View {
    var body: some View { Rectangle().fill(Tokens.sageA(0.2)).frame(width: 1, height: 28) }
}

/// `border: 1px dashed rgba(74,103,65,.22)`
struct DashedRule: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in p.move(to: CGPoint(x: 0, y: 0.5)); p.addLine(to: CGPoint(x: geo.size.width, y: 0.5)) }
                .stroke(Tokens.sageA(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .frame(height: 1)
    }
}
