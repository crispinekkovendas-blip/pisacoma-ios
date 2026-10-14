import Combine
import SwiftUI

// quiz-view.css / quiz index.tsx tokens
private let bg = Tokens.bg
private let card = Tokens.bg2
private let lineColor = Tokens.border
private let gold = Tokens.accent
private let goldLight = Tokens.accentLight
private let textColor = Color(hex: 0xE6E9EE)
private let goldGradient = LinearGradient(colors: [gold, goldLight], startPoint: .leading, endPoint: .trailing)

struct QuizUi: Equatable {
    var pack: QuizPack? = nil
    var state = QuizState()
    var notFound = false
    var levels: [QuizLevel] { pack?.levels ?? QuizState.defaultLevels }
}

/// Loads a pack and keeps its QuizState in sync with `quiz.<slug>.v1`, exactly as the site persists it.
@MainActor
final class QuizModel: ObservableObject {
    @Published private(set) var ui = QuizUi()
    private let app: AppModel
    private let slug: String

    init(app: AppModel, slug: String) {
        self.app = app
        self.slug = slug
        Task {
            do {
                guard let pack = try await app.quizzes.pack(slug) else { ui.notFound = true; return }
                ui = QuizUi(pack: pack, state: QuizState.fromJson(app.userState.string(UserState.Keys.quiz(slug))))
            } catch let e as ContentMissing {
                ContentErrors.report(e, app: app)
            } catch { ui.notFound = true }
        }
    }

    private func change(_ f: (QuizState) -> QuizState, persist: Bool) {
        ui.state = f(ui.state)
        if persist { app.userState.set(UserState.Keys.quiz(slug), ui.state.toJson()) }
    }

    func pick(_ qN: Int, _ letter: String) { change({ $0.requestCommit(qN, letter) }, persist: false) }
    func cancel() { change({ $0.cancel() }, persist: false) }
    func confirm() { change({ $0.confirm() }, persist: true) }
    func submit() { change({ $0.submit() }, persist: true) }
    func reset() { change({ $0.reset() }, persist: true) }
}

@MainActor
final class QuizIndexModel: ObservableObject {
    @Published private(set) var packs: [QuizPack] = []
    init(app: AppModel) {
        Task {
            do { packs = try await app.quizzes.packs() } catch let e as ContentMissing { ContentErrors.report(e, app: app) } catch {}
        }
    }
}

private struct Crumbs: View {
    let first: String
    let second: String
    var onFirst: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            if let onFirst { Text(first.uppercased()).font(Fonts.inter(12.5)).tracking(1).foregroundStyle(gold).pressable(scale: 0.98, action: onFirst) }
            else { Text(first.uppercased()).font(Fonts.inter(12.5)).tracking(1).foregroundStyle(gold) }
            Text("/").font(Fonts.inter(12.5)).foregroundStyle(Color.white.opacity(0.25))
            Text(second.uppercased()).font(Fonts.inter(12.5)).tracking(1).foregroundStyle(Color.white.opacity(0.7))
            Spacer()
        }
    }
}

private struct Badge: View {
    let text: String
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(gold).frame(width: 6, height: 6)
            Text(text.uppercased()).font(Fonts.inter(11.8)).tracking(1.1).foregroundStyle(goldLight)
        }
        .padding(.horizontal, 15).padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: 0xC9963B, alpha: 0.06)))
        .overlay(Capsule().stroke(Color(hex: 0xC9963B, alpha: 0.45), lineWidth: 1))
    }
}

/// `.hero` of the quiz pages: the gold glow over the dark base.
private let heroGradient = LinearGradient(colors: [Color(hex: 0x0F1923), bg], startPoint: .top, endPoint: .bottom)

/// The site's /quiz: the packs, newest first.
struct QuizIndexView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var model: QuizIndexModel
    init() { _model = StateObject(wrappedValue: QuizIndexModel(app: AppModel.shared)) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    Crumbs(first: "Escuela Sabática", second: "Quizzes")
                    Spacer().frame(height: 22)
                    Badge(text: "Quizzes oficiales · Iglesia Adventista del Séptimo Día")
                    Spacer().frame(height: 22)
                    Text("Quizzes de la Escuela Sabática").font(Fonts.playfair(38, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                    Spacer().frame(height: 14)
                    Text("Pon a prueba lo que aprendiste en la lección de cada semana. Selecciona una pregunta a la vez, confírmala, y al final revisa tus respuestas.")
                        .font(Fonts.inter(16)).lineSpacing(6).foregroundStyle(Color.white.opacity(0.7)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24).padding(.vertical, 48)
                .background(heroGradient)
                Rectangle().fill(lineColor).frame(height: 1)
                Spacer().frame(height: 28)
                ForEach(model.packs) { q in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text("L\(q.lessonNumber)").font(Fonts.playfair(14, weight: .semibold)).foregroundStyle(goldLight).padding(.horizontal, 9).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xC9963B, alpha: 0.14)))
                            Text(q.badge.uppercased()).font(Fonts.inter(11)).tracking(1).foregroundStyle(Color.white.opacity(0.55))
                        }
                        Text(q.title).font(Fonts.playfair(21, weight: .semibold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        Text("\(q.questions.count) preguntas · respuestas confirmadas una a una").font(Fonts.inter(13.5)).foregroundStyle(Color.white.opacity(0.6))
                        HStack(spacing: 8) {
                            Text("Comenzar quiz").font(Fonts.inter(14, weight: .semibold)).foregroundStyle(goldLight)
                            Text("→").font(Fonts.inter(14)).foregroundStyle(goldLight)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(RoundedRectangle(cornerRadius: 16).fill(card))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(lineColor, lineWidth: 1))
                    .pressable(scale: 0.985, tag: "quiz-card-\(q.slug)") { router.go(.quizPack(slug: q.slug)) }
                    .padding(.horizontal, 20).padding(.bottom, 14)
                }
                Spacer().frame(height: 30)
                SiteFooter()
            }
        }
        .background(bg)
        .uiId("quiz-index")
    }
}

/// One answer row of a question card: selected / confirmed / right / wrong states, as the site's `.opt`.
private struct QuizOptionRow: View {
    let q: QuizQuestion
    let opt: QuizOption
    let selected: Bool
    let submitted: Bool
    let disabled: Bool
    let onPick: () -> Void

    var body: some View {
        let showRight = submitted && opt.letter == q.correct
        let showWrong = submitted && selected && opt.letter != q.correct
        let bgc: Color = showRight ? Color(hex: 0x2EA043, alpha: 0.1) : (showWrong ? Color(hex: 0xDA3633, alpha: 0.1) : (selected ? Color(hex: 0xC9963B, alpha: 0.1) : bg))
        let bd: Color = showRight ? Color(hex: 0x2EA043) : (showWrong ? Color(hex: 0xDA3633) : (selected ? gold : lineColor))
        let fg: Color = showRight ? Color(hex: 0xC8E6CD) : (showWrong ? Color(hex: 0xF0C4C2) : textColor)
        HStack(spacing: 13) {
            Text(opt.letter)
                .font(Fonts.inter(13.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(lineColor, lineWidth: 1))
            Text(opt.text).font(Fonts.inter(15)).lineSpacing(3).foregroundStyle(fg).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if showRight { Text("✓").font(.system(size: 16)).foregroundStyle(Color(hex: 0x2EA043)) }
            if showWrong { Text("✕").font(.system(size: 16)).foregroundStyle(Color(hex: 0xDA3633)) }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 10).fill(bgc))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(bd, lineWidth: 1))
        .opacity(disabled && !selected && !showRight ? 0.6 : 1)
        .pressable(scale: 0.99, enabled: !disabled, tag: "q\(q.n)-\(opt.letter)", action: onPick)
        .padding(.bottom, 8)
    }
}

/// The site's /quiz/<slug> (components/quiz-view.tsx): hero + memory verse, sticky progress, question cards, submit/results, confirm modal.
struct QuizView: View {
    let slug: String
    @EnvironmentObject private var router: Router
    @StateObject private var model: QuizModel

    init(slug: String) {
        self.slug = slug
        _model = StateObject(wrappedValue: QuizModel(app: AppModel.shared, slug: slug))
    }

    var body: some View {
        let ui = model.ui
        if ui.notFound {
            VStack { Text("Quiz no encontrado").font(Fonts.playfair(24)).foregroundStyle(.white); Spacer() }.padding(24).frame(maxWidth: .infinity).background(bg)
        } else if let pack = ui.pack {
            let st = ui.state
            let total = pack.questions.count
            ZStack {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(st.committedCount)).font(Fonts.inter(15, weight: .bold)).foregroundStyle(goldLight)
                            Text("/ \(total) confirmadas").font(Fonts.inter(13)).foregroundStyle(Color.white.opacity(0.55)).accessibilityIdentifier("quiz-progress")
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule().fill(goldGradient).frame(width: geo.size.width * CGFloat(st.pct(pack)) / 100)
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color(hex: 0x0D1117, alpha: 0.92))
                    Rectangle().fill(lineColor).frame(height: 1)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            hero(pack)
                            ForEach(pack.questions, id: \.n) { q in questionCard(q, st: st) }
                            footer(pack, st: st, ui: ui, total: total)
                            SiteFooter()
                        }
                    }
                    .uiId("quiz-page")
                }
                .background(bg)
                if let p = st.pending, let q = pack.questions.first(where: { $0.n == p.qN }), let opt = q.options.first(where: { $0.letter == p.letter }) {
                    confirmModal(q, opt: opt)
                }
            }
        } else {
            Color.clear.background(bg)
        }
    }

    private func hero(_ pack: QuizPack) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Crumbs(first: "Quizzes", second: "Lección \(pack.lessonNumber) · Quiz") { router.go(.quiz) }
                Spacer().frame(height: 20)
                Badge(text: pack.badge)
                Spacer().frame(height: 22)
                Text(pack.title).font(Fonts.playfair(36, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                Spacer().frame(height: 14)
                Text(pack.subtitle).font(Fonts.inter(16)).lineSpacing(6).foregroundStyle(Color.white.opacity(0.7)).multilineTextAlignment(.center)
                Spacer().frame(height: 30)
                VStack(alignment: .leading, spacing: 8) {
                    Text("TEXTO PARA MEMORIZAR").font(Fonts.inter(11)).tracking(1.4).foregroundStyle(gold)
                    Text(pack.memorize.text).font(Fonts.playfair(17, weight: .semibold)).lineSpacing(6).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                    Text("— \(pack.memorize.ref)").font(Fonts.inter(13)).foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24).padding(.vertical, 20)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(lineColor, lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.vertical, 40)
            .background(heroGradient)
            Rectangle().fill(lineColor).frame(height: 1)
            Spacer().frame(height: 24)
        }
    }

    private func questionCard(_ q: QuizQuestion, st: QuizState) -> some View {
        let locked = st.committed[q.n]
        let chosen = locked ?? (st.pending?.qN == q.n ? st.pending?.letter : nil)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", q.n)).font(Fonts.playfair(16, weight: .semibold)).foregroundStyle(goldLight).frame(width: 38, height: 38).background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xC9963B, alpha: 0.14)))
                VStack(alignment: .leading, spacing: 5) {
                    if let ref = q.ref { Text(ref.uppercased()).font(Fonts.inter(11)).tracking(1.2).foregroundStyle(gold) }
                    Text(q.text).font(Fonts.playfair(18, weight: .semibold)).lineSpacing(4).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer().frame(height: 16)
            ForEach(q.options, id: \.letter) { opt in
                QuizOptionRow(
                    q: q, opt: opt,
                    selected: chosen == opt.letter,
                    submitted: st.submitted,
                    disabled: locked != nil || st.submitted
                ) { model.pick(q.n, opt.letter) }
            }
            if locked != nil && !st.submitted {
                Spacer().frame(height: 6)
                Text("RESPUESTA CONFIRMADA").font(Fonts.inter(12.5, weight: .semibold)).tracking(1).foregroundStyle(Color(hex: 0xE8B85A, alpha: 0.85)).accessibilityIdentifier("q\(q.n)-locked")
            }
            if st.submitted, let ex = q.explain {
                Spacer().frame(height: 16)
                HStack(spacing: 0) {
                    Rectangle().fill(gold).frame(width: 3)
                    Text("Nota: \(ex)").font(Fonts.inter(14.7)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.78)).padding(.horizontal, 16).padding(.vertical, 14).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xC9963B, alpha: 0.06))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 8, topTrailingRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 20)
        .background(RoundedRectangle(cornerRadius: 16).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(lineColor, lineWidth: 1))
        .padding(.horizontal, 20).padding(.bottom, 16)
    }

    private func footer(_ pack: QuizPack, st: QuizState, ui: QuizUi, total: Int) -> some View {
        VStack(spacing: 0) {
            if !st.submitted {
                let all = st.allCommitted(pack)
                Text("Revisar mis respuestas").font(Fonts.inter(16, weight: .semibold)).foregroundStyle(bg)
                    .padding(.horizontal, 32).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 10).fill(goldGradient))
                    .opacity(all ? 1 : 0.45)
                    .pressable(scale: 0.97, enabled: all, tag: "quiz-submit") { model.submit() }
                if !all {
                    Spacer().frame(height: 14)
                    Text("Te faltan \(total - st.committedCount) respuestas por confirmar.").font(Fonts.inter(13.8)).foregroundStyle(Color.white.opacity(0.5))
                }
            } else {
                let score = st.score(pack)
                let tier = QuizState.tier(score, ui.levels)
                VStack(spacing: 0) {
                    Text("RESULTADO").font(Fonts.inter(11)).tracking(1.6).foregroundStyle(gold)
                    Spacer().frame(height: 10)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(score)).font(Fonts.playfair(72, weight: .semibold)).foregroundStyle(goldLight)
                        Text("/").font(Fonts.inter(24)).foregroundStyle(Color.white.opacity(0.4))
                        Text(String(total)).font(Fonts.inter(24)).foregroundStyle(Color.white.opacity(0.7))
                    }
                    Spacer().frame(height: 16)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(goldGradient).frame(width: total == 0 ? 0 : geo.size.width * CGFloat(score) / CGFloat(total))
                        }
                    }
                    .frame(height: 6)
                    Spacer().frame(height: 22)
                    Text("Nivel \(tier.name)").font(Fonts.playfair(30, weight: .semibold)).foregroundStyle(.white)
                    Spacer().frame(height: 10)
                    Text(tier.desc).font(Fonts.inter(15)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.7)).multilineTextAlignment(.center)
                    Spacer().frame(height: 24)
                    Text("Intentar de nuevo").font(Fonts.inter(16, weight: .semibold)).foregroundStyle(bg).padding(.horizontal, 32).padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 10).fill(goldGradient))
                        .pressable(scale: 0.97, tag: "quiz-reset") { model.reset() }
                    Spacer().frame(height: 10)
                    Text("Volver a la lección").font(Fonts.inter(15, weight: .semibold)).foregroundStyle(goldLight).padding(.horizontal, 27).padding(.vertical, 15)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(gold, lineWidth: 1))
                        .pressable(scale: 0.97) { router.go(.escuela) }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24).padding(.vertical, 38)
                .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [card, Color(hex: 0x11151C)], startPoint: .top, endPoint: .bottom)))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(lineColor, lineWidth: 1))
                .uiId("quiz-results")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 40)
    }

    private func confirmModal(_ q: QuizQuestion, opt: QuizOption) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { model.cancel() }
            VStack(alignment: .leading, spacing: 0) {
                Text("PREGUNTA \(q.n)").font(Fonts.inter(11)).tracking(1.4).foregroundStyle(gold)
                Spacer().frame(height: 8)
                Text("¿Confirmar esta respuesta?").font(Fonts.playfair(24, weight: .semibold)).foregroundStyle(.white)
                Spacer().frame(height: 8)
                Text("Una vez confirmada no podrás cambiarla, ni siquiera al recargar la página.").font(Fonts.inter(14.5)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 16)
                HStack(alignment: .top, spacing: 10) {
                    Text("\(opt.letter).").font(Fonts.inter(15, weight: .bold)).foregroundStyle(goldLight)
                    Text(opt.text).font(Fonts.inter(15)).lineSpacing(3).foregroundStyle(textColor).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0xC9963B, alpha: 0.1)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(gold, lineWidth: 1))
                Spacer().frame(height: 18)
                HStack(spacing: 10) {
                    Text("Cancelar").font(Fonts.inter(15, weight: .semibold)).foregroundStyle(Color.white.opacity(0.78)).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0x2D343D), lineWidth: 1))
                        .pressable(scale: 0.97, tag: "confirm-no") { model.cancel() }
                    Text("Sí, confirmar").font(Fonts.inter(15, weight: .semibold)).foregroundStyle(bg).frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 10).fill(goldGradient))
                        .pressable(scale: 0.97, tag: "confirm-yes") { model.confirm() }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 26)
            .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [card, Color(hex: 0x11151C)], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0x2D343D), lineWidth: 1))
            .padding(24)
            .uiId("quiz-confirm")
        }
    }
}
