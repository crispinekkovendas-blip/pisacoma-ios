import Lottie
import SwiftUI

private let basalt = Tokens.basalt
private let parchment = Tokens.parchment
private let lightBg = Color(hex: 0xEFE6CC)

/// «Un día en el Altiplano»: eleven full-height scenes, each a looping Lottie over its poster with the section's text, as the site's home.
struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var router: Router
    @StateObject private var model: HomeModel
    @Environment(\.openURL) private var openURL

    init() { _model = StateObject(wrappedValue: HomeModel(app: AppModel.shared)) }

    var body: some View {
        let s = model.state
        GeometryReader { geo in
            let portrait = geo.size.height >= geo.size.width
            // site: portrait sections are max(600px, 100svh − 66px); landscape clamp(560px, 88svh, 1000px)
            let sceneH: CGFloat = portrait ? max(600, geo.size.height) : min(1000, max(560, geo.size.height * 0.88))
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Scene(id: "inicio", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("Pisacoma", portada: true)
                            SceneLede("Iglesia Adventista del Séptimo Día en el Altiplano de Puno, a 3.940 metros sobre el mar.")
                            Cta("Visítanos un sábado", id: "inicio") { router.go(.visitanos) }
                        }
                        Scene(id: "himnario", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("Himnario")
                            SceneLede("1.823 himnos en español y portugués, con la letra completa y audio para cantar en casa o en el templo.")
                            Cta("Abrir el himnario", id: "himnario") { router.go(.himnario) }
                        }
                        Scene(id: "videos", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("Videos")
                            SceneLede("Sermones y la lección de la semana de cuatro pastores, reunidos en un solo lugar.")
                            Cta("Ver los videos", id: "videos") { router.go(.videos) }
                        }
                        Scene(id: "escuela", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("Escuela Sabática")
                            SceneLede(s.escEnded ? "«\(s.quarterTitle)». El trimestre terminó: puedes repasar sus \(s.weeksTotal) lecciones." : "«\(s.quarterTitle)». Esta semana estudiamos la lección \(s.escWeek) de \(s.weeksTotal).")
                            Cta(s.escEnded ? "Repasar el trimestre" : "Abrir la lección \(s.escWeek)", id: "escuela") { router.go(.escuela) }
                        }
                        Scene(id: "biblia", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("La Biblia")
                            SceneLede("La Reina-Valera 1960 completa, con tus notas y marcadores guardados en el teléfono.")
                            Cta("Leer la Biblia", id: "biblia") { router.go(.biblia(book: nil, chapter: nil, verse: nil)) }
                        }
                        Scene(id: "diccionario", height: sceneH, portrait: portrait, paused: s.paused, light: true) {
                            SceneTitle("Diccionario", light: true)
                            SceneLede("¿Una palabra difícil en la lección o en un himno? Búscala y lee su significado.", light: true)
                            Cta("Buscar una palabra", id: "diccionario", light: true) { router.go(.diccionario) }
                        }
                        Scene(id: "egw", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("Elena G. de White")
                            SceneLede("25 libros en español para leer por capítulo, desde El camino a Cristo hasta El conflicto de los siglos.")
                            Cta("Entrar a la biblioteca", id: "egw") { router.go(.egw) }
                        }
                        Scene(id: "quiz", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("Quiz de la lección")
                            SceneLede("Responde las preguntas de la semana y guarda tu nivel, de Acán a Caleb.")
                            Cta("Empezar el quiz", id: "quiz") { router.go(.quiz) }
                        }
                        Scene(id: "quien", height: sceneH, portrait: portrait, paused: s.paused) {
                            SceneTitle("¿Quién?")
                            SceneLede("Una ruleta para elegir quién ora, lee o canta, sin repetir a la misma persona.")
                            Cta("Girar la ruleta", id: "quien") { router.go(.quien) }
                        }
                        if !s.anuncios.isEmpty { avisos(s.anuncios) }
                        Scene(id: "sabado", height: sceneH, portrait: portrait, paused: s.paused, strongVeil: true) {
                            let sab = s.sabbath
                            SceneTitle(sab?.isSabbath == true ? "Feliz sábado" : "El sábado empieza al ponerse el sol")
                            if let sab {
                                HStack(alignment: .top, spacing: 28) {
                                    SolItem(label: "\(Zmanim.dayLabel(sab.friday)), empieza", clock: Zmanim.clock12(sab.start))
                                    SolItem(label: "\(Zmanim.dayLabel(sab.saturday)), termina", clock: Zmanim.clock12(sab.end))
                                }
                                .padding(.bottom, 20)
                                .accessibilityIdentifier("sabado-times")
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(s.schedule.enumerated()), id: \.offset) { _, it in
                                    HStack(spacing: 5) {
                                        Text("\(it.day) \(it.time) \(it.suffix)").font(Fonts.dmSans(16, weight: .semibold)).foregroundStyle(parchment)
                                        Text(it.name).font(Fonts.dmSans(16)).foregroundStyle(parchment)
                                    }
                                }
                            }
                            .padding(.bottom, 28)
                            Cta("Añadir al calendario", id: "sabado") { router.go(.visitanos) }
                        }
                        Scene(id: "noche", height: sceneH, portrait: portrait, paused: s.paused) {
                            HStack(spacing: 16) {
                                IconView(name: "sda_symbol", color: Tokens.ochreLight).frame(width: 60, height: 54)
                                Text("Iglesia Adventista del Séptimo Día de Pisacoma").font(Fonts.fraunces(25.6, weight: .regular)).foregroundStyle(parchment)
                            }
                            .padding(.bottom, 16)
                            SceneLede("Distrito de Pisacoma, Chucuito, Puno. Te esperamos el sábado.")
                            Cta("Cómo llegar", id: "noche") { router.go(.visitanos) }
                            Spacer().frame(height: 44)
                            creditos(s.photos)
                            Spacer().frame(height: 24)
                        }
                    }
                }
                .accessibilityIdentifier("home")
                // .escenas-pausa — fixed, bottom right; never tied to the system's reduce-motion setting
                ZStack {
                    Circle().fill(Color(hex: 0x2A2620, alpha: 0.72))
                    Circle().stroke(parchment.opacity(0.3), lineWidth: 1)
                    IconView(name: s.paused ? "ic_play" : "ic_pause", color: parchment).frame(width: 18, height: 18)
                }
                .frame(width: 44, height: 44)
                .pressable(scale: 0.95, tag: s.paused ? "home-pause-on" : "home-pause") { model.togglePause() }
                .accessibilityLabel(s.paused ? "Reproducir las animaciones" : "Pausar las animaciones")
                .padding(16)
            }
            .background(basalt)
        }
    }

    private func avisos(_ list: [AnuncioView]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Esta semana en la iglesia").font(Fonts.fraunces(32, weight: .regular)).foregroundStyle(basalt)
            Spacer().frame(height: 24)
            ForEach(list) { a in
                Rectangle().fill(Color(hex: 0x2A2620, alpha: 0.18)).frame(height: 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text((a.isToday ? "Hoy" : a.dateLabel) + (a.time.map { ", \($0)" } ?? ""))
                        .font(Fonts.dmSans(15, weight: a.isToday ? .bold : .medium))
                        .foregroundStyle(a.isToday ? Color(hex: 0x744612) : Color(hex: 0x4B5733))
                    Text(a.title).font(Fonts.fraunces(20.8, weight: .medium)).foregroundStyle(basalt)
                    if let d = a.detail { Text(d).font(Fonts.dmSans(15)).lineSpacing(4).foregroundStyle(Color(hex: 0x3F3A30)) }
                }
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 48)
        .background(Tokens.olivePale)
        .accessibilityIdentifier("avisos")
    }

    private func creditos(_ photos: [HomePhoto]) -> some View {
        let dim = parchment.opacity(0.78)
        var t = Text("Fotos animadas a partir de Wikimedia Commons: ")
        for (i, p) in photos.enumerated() {
            t = t + Text(p.title).underline() + Text(", de \(p.author) (") + Text(p.license).underline() + Text(i < photos.count - 1 ? "); " : "). ")
        }
        t = t + Text("Los videos de esas secciones se comparten con la misma licencia.")
        return t.font(Fonts.dmSans(12.8)).foregroundStyle(dim).lineSpacing(4).accessibilityIdentifier("creditos")
    }
}

/// One section: poster → Lottie (portrait/landscape cut) → veil → text, bottom-aligned.
private struct Scene<Content: View>: View {
    let id: String
    let height: CGFloat
    let portrait: Bool
    let paused: Bool
    var light = false
    var strongVeil = false
    @ViewBuilder let content: () -> Content

    init(id: String, height: CGFloat, portrait: Bool, paused: Bool, light: Bool = false, strongVeil: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.id = id; self.height = height; self.portrait = portrait; self.paused = paused; self.light = light; self.strongVeil = strongVeil; self.content = content
    }

    private var root: URL { Bundle.main.resourceURL!.appendingPathComponent("Content") }

    var body: some View {
        let cut = portrait ? "portrait" : "landscape"
        let dark = Color(hex: 0x16120C)
        ZStack(alignment: .bottomLeading) {
            (light ? lightBg : basalt)
            if let ui = UIImage(contentsOfFile: root.appendingPathComponent("home/\(id)-\(cut).jpg").path) {
                Image(uiImage: ui).resizable().scaledToFill().frame(height: height).clipped()
            }
            SceneLottie(file: root.appendingPathComponent("home/lottie/\(id)-\(cut).json"), imagesRoot: root, paused: paused)
                .frame(height: height)
                .clipped()
            // veil: bottom (and left on landscape), stronger on #sabado, pale on the light scene
            Group {
                if light {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: lightBg.opacity(0.7), location: 0.4), .init(color: lightBg.opacity(0.96), location: 1)], startPoint: .top, endPoint: .bottom)
                } else if strongVeil {
                    LinearGradient(stops: [.init(color: dark.opacity(0.28), location: 0), .init(color: dark.opacity(0.6), location: 0.55), .init(color: dark.opacity(0.88), location: 1)], startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.4), .init(color: dark.opacity(0.55), location: 0.68), .init(color: dark.opacity(0.86), location: 1)], startPoint: .top, endPoint: .bottom)
                }
            }
            if !portrait {
                let base = light ? lightBg : dark
                LinearGradient(stops: [.init(color: base.opacity(light ? 0.85 : 0.62), location: 0), .init(color: base.opacity(0.3), location: 0.36), .init(color: .clear, location: 0.58)], startPoint: .leading, endPoint: .trailing)
            }
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxWidth: portrait ? .infinity : nil, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .accessibilityIdentifier("scene-\(id)")
    }
}

/// A looping Lottie file whose image layers resolve under the content root (`home/lottie/img/`, `covers/`).
private struct SceneLottie: View {
    let file: URL
    let imagesRoot: URL
    let paused: Bool
    @State private var animation: LottieAnimation? = nil

    var body: some View {
        LottieView(animation: animation)
            .playbackMode(paused ? .paused : .playing(.toProgress(1, loopMode: .loop)))
            .imageProvider(FilepathImageProvider(filepath: imagesRoot.path))
            .configure { $0.contentMode = .scaleAspectFill }
            .resizable()
            .task(id: file) {
                if animation == nil { animation = LottieAnimation.filepath(file.path) }
            }
    }
}

private struct SceneTitle: View {
    let text: String
    var portada = false
    var light = false
    init(_ text: String, portada: Bool = false, light: Bool = false) { self.text = text; self.portada = portada; self.light = light }
    var body: some View {
        Text(text)
            .font(Fonts.fraunces(portada ? 68 : 44, weight: portada ? .light : .regular))
            .tracking(portada ? -0.03 * 68 : -0.015 * 44)
            .lineSpacing(-4)
            .foregroundStyle(light ? basalt : parchment)
            .padding(.bottom, 14)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SceneLede: View {
    let text: String
    var light = false
    init(_ text: String, light: Bool = false) { self.text = text; self.light = light }
    var body: some View {
        Text(text).font(Fonts.dmSans(16.8)).lineSpacing(6).foregroundStyle(light ? basalt : parchment).padding(.bottom, 28).fixedSize(horizontal: false, vertical: true)
    }
}

private struct Cta: View {
    let label: String
    let id: String
    var light = false
    let action: () -> Void
    init(_ label: String, id: String, light: Bool = false, action: @escaping () -> Void) { self.label = label; self.id = id; self.light = light; self.action = action }
    var body: some View {
        Text(label)
            .font(Fonts.dmSans(16, weight: .semibold))
            .foregroundStyle(light ? parchment : basalt)
            .padding(.horizontal, 24)
            .frame(height: 48)
            .background(Capsule().fill(light ? basalt : parchment))
            .pressable(scale: 0.98, tag: "scene-\(id)-action", action: action)
    }
}

private struct SolItem: View {
    let label: String
    let clock: Zmanim.Clock12
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(Fonts.dmSans(16, weight: .medium)).foregroundStyle(parchment)
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(clock.time).font(Fonts.fraunces(44, weight: .regular)).foregroundStyle(parchment)
                Text(clock.suffix).font(Fonts.dmSans(16, weight: .semibold)).foregroundStyle(parchment)
            }
        }
    }
}
