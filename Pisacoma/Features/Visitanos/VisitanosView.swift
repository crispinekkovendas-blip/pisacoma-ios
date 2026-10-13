import SwiftUI

// site visitanos/index.tsx TIPS
private let tips: [(String, String)] = [
    ("Llega unos minutos antes", "La Escuela Sabática empieza a las 9:30. Con 10 o 15 minutos de margen hay tiempo para saludar y encontrar sitio."),
    ("Abrígate bien", "A 3.940 metros las mañanas son frías todo el año, y en invierno la temperatura puede bajar de cero."),
    ("Ven como eres", "No hace falta ser miembro ni conocer a nadie para visitarnos: todos son bienvenidos."),
]

/// The site's /visitanos: horarios + sunset + calendar, dónde estamos, tu primer sábado, nuestra historia, a qué pertenecemos.
struct VisitanosView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var router: Router
    @Environment(\.openURL) private var openURL
    @State private var church: Church? = nil

    var body: some View {
        ScrollView {
            if let c = church {
                content(c)
                SiteFooter()
            }
        }
        .accessibilityIdentifier("visitanos")
        .task { church = try? await app.church.church() }
    }

    private func content(_ c: Church) -> some View {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let sab = Zmanim.sabbathTimes(now)
        let start = Zmanim.clock12(sab.start)
        let end = Zmanim.clock12(sab.end)
        let mapsUrl = "https://www.google.com/maps/search/?api=1&query=\(c.location.lat),\(c.location.lng)"
        let osmUrl = "https://www.openstreetmap.org/?mlat=\(c.location.lat)&mlon=\(c.location.lng)#map=14/\(c.location.lat)/\(c.location.lng)"
        return VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 44)
            EyebrowLine("— Visítanos · Pisacoma, Chucuito · Puno")
            Spacer().frame(height: 18)
            PageTitle(titleWithEm("Te esperamos", "este sábado."))
            Spacer().frame(height: 22)
            Lede("Una iglesia adventista a 3.940 metros, en el Altiplano. Aquí tienes los horarios, dónde estamos y lo que conviene saber antes de tu primera visita.")
            Spacer().frame(height: 36)

            BlockHead("— Horarios")
            ForEach(Array(c.schedule.enumerated()), id: \.offset) { i, s in
                RowItem(first: i == 0, title: s.name, caption: s.day) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Numeral(s.time)
                        Text(s.suffix).font(Fonts.fraunces(12, weight: .regular, italic: true)).foregroundStyle(Ochre.label)
                    }
                }
            }
            Spacer().frame(height: 18)
            VStack(alignment: .leading, spacing: 0) {
                EyebrowLine("Puesta del sol esta semana · Pisacoma", color: Ochre.label, size: 10.5)
                Spacer().frame(height: 10)
                SolLine(time: start.time, suffix: start.suffix, label: "\(Zmanim.dayLabel(sab.friday)) · empieza el sábado")
                Spacer().frame(height: 6)
                SolLine(time: end.time, suffix: end.suffix, label: "\(Zmanim.dayLabel(sab.saturday)) · termina el sábado")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xFBF9EF, alpha: 0.7)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xB8924F, alpha: 0.35), lineWidth: 1))
            .accessibilityIdentifier("sol")
            Spacer().frame(height: 18)
            Text("Recibe los horarios y la puesta del sol de cada sábado en el calendario de tu teléfono, con un aviso antes de cada reunión. Se actualiza solo.")
                .font(Fonts.inter(14.5)).lineSpacing(5).foregroundStyle(Tokens.ledeInk).fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 12)
            HStack(spacing: 8) {
                // iOS subscribes to the site's calendar natively through webcal://
                VPill(label: "Añadir al calendario", tag: "add-calendar") { openURL(URL(string: "webcal://quiz-qwik.vercel.app/calendario.ics")!) }
                VPill(label: "Suscribirse (.ics)", ghost: true) { openURL(URL(string: "\(AudioUrls.site)/calendario.ics")!) }
            }
            Spacer().frame(height: 14)
            HStack(spacing: 4) {
                Text("¿Quieres llegar preparado? Lee").font(Fonts.inter(14)).foregroundStyle(Tokens.ledeInk)
                Text("la lección de esta semana").font(Fonts.inter(14, weight: .semibold)).foregroundStyle(Tokens.sage).pressable(scale: 0.98) { router.go(.escuela) }
            }
            HStack(spacing: 4) {
                Text("o busca los himnos en").font(Fonts.inter(14)).foregroundStyle(Tokens.ledeInk)
                Text("el himnario.").font(Fonts.inter(14, weight: .semibold)).foregroundStyle(Tokens.sage).pressable(scale: 0.98) { router.go(.himnario) }
            }
            Spacer().frame(height: 40)

            BlockHead("— Dónde estamos")
            Text("Distrito de \(c.location.district), provincia de \(c.location.province), región \(c.location.region), junto a la frontera con Bolivia.")
                .font(Fonts.fraunces(18, weight: .regular)).lineSpacing(6).foregroundStyle(Tokens.inkDeep).fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 16)
            HStack(alignment: .top, spacing: 28) {
                Fact(label: "Altitud", value: c.location.altitude)
                Fact(label: "Coordenadas", value: String(format: "%.4f° S · %.4f° O", abs(c.location.lat), abs(c.location.lng)))
            }
            Spacer().frame(height: 16)
            HStack(spacing: 8) {
                VPill(label: "Abrir en Google Maps ↗", tag: "open-maps") { openURL(URL(string: mapsUrl)!) }
                VPill(label: "OpenStreetMap ↗", ghost: true) { openURL(URL(string: osmUrl)!) }
            }
            Spacer().frame(height: 10)
            Text("Las coordenadas marcan el centro de Pisacoma.").font(Fonts.fraunces(13, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
            Spacer().frame(height: 18)
            VStack(spacing: 0) {
                Compass().frame(width: 180, height: 180)
                Text("Pisacoma · \(c.location.altitude)").font(Fonts.fraunces(12.5, weight: .regular, italic: true)).foregroundStyle(Tokens.sageText)
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(height: 40)

            BlockHead("— Tu primer sábado")
            ForEach(Array(tips.enumerated()), id: \.offset) { i, tip in
                RowItem(first: i == 0, title: tip.0, caption: tip.1, prose: true) { Numeral(String(format: "%02d", i + 1)) }
            }
            Spacer().frame(height: 40)

            BlockHead("— Nuestra historia")
            Text("Más de un siglo de fe adventista en el Altiplano. Pisacoma está en el origen de esa historia.")
                .font(Fonts.inter(15)).lineSpacing(5).foregroundStyle(Tokens.ledeInk).fixedSize(horizontal: false, vertical: true)
            Spacer().frame(height: 14)
            ForEach(Array(c.timeline.enumerated()), id: \.offset) { i, t in
                RowItem(first: i == 0, title: nil, caption: t.text, prose: true, dark: true) { Numeral(t.year, small: t.year.count > 4) }
            }
            Spacer().frame(height: 22)
            ForEach(Array(c.pioneers.enumerated()), id: \.offset) { _, p in
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLine(p.role, color: Ochre.label, size: 10.5)
                    Text(p.name).font(Fonts.fraunces(19, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
                    Text(p.bio).font(Fonts.inter(14.5)).lineSpacing(5).foregroundStyle(Tokens.ledeInk).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Tokens.sageA(0.16), lineWidth: 1))
                .padding(.bottom, 12)
            }
            Spacer().frame(height: 28)

            BlockHead("— A qué pertenecemos")
            ForEach(Array(c.hierarchy.enumerated()), id: \.offset) { i, h in
                HStack(spacing: 12) {
                    Circle().fill(i == 0 ? Tokens.sage : Tokens.sageA(0.3)).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.name).font(Fonts.fraunces(16, weight: i == 0 ? .semibold : .medium)).foregroundStyle(i == 0 ? Tokens.inkDeep : Tokens.ink)
                        if !h.place.isEmpty { EyebrowLine(h.place, color: Tokens.sageText, size: 10, tracking: 1.4) }
                    }
                }
                .padding(.bottom, 10)
            }
            Spacer().frame(height: 14)
            Text("\(c.mission.name) · \(c.mission.address), \(c.mission.city)").font(Fonts.fraunces(13, weight: .regular, italic: true)).lineSpacing(4).foregroundStyle(Tokens.sageText)
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 20)
    }
}

struct BlockHead: View {
    let label: String
    init(_ label: String) { self.label = label }
    var body: some View {
        HStack(spacing: 14) {
            EyebrowLine(label, color: Tokens.sage, size: 11)
            OrnamentRule()
        }
        .padding(.bottom, 16)
    }
}

private struct Numeral: View {
    let text: String
    var small = false
    init(_ text: String, small: Bool = false) { self.text = text; self.small = small }
    var body: some View {
        Text(text).font(Fonts.fraunces(small ? 15 : 22, weight: .bold, italic: true)).tracking(-0.03 * 22).foregroundStyle(Ochre.numeral)
    }
}

private struct RowItem<Num: View>: View {
    let first: Bool
    let title: String?
    let caption: String
    var prose = false
    var dark = false
    @ViewBuilder let num: () -> Num

    init(first: Bool, title: String?, caption: String, prose: Bool = false, dark: Bool = false, @ViewBuilder num: @escaping () -> Num) {
        self.first = first; self.title = title; self.caption = caption; self.prose = prose; self.dark = dark; self.num = num
    }

    var body: some View {
        VStack(spacing: 0) {
            if !first { Hairline(alpha: 0.10) }
            HStack(alignment: prose ? .top : .center, spacing: 16) {
                num().frame(width: 62, alignment: .trailing)
                VStack(alignment: .leading, spacing: 3) {
                    if let title { Text(title).font(Fonts.fraunces(16.5, weight: .medium)).foregroundStyle(Tokens.ink) }
                    Text(caption)
                        .font(prose ? Fonts.inter(14) : Fonts.fraunces(12, weight: .regular, italic: true))
                        .lineSpacing(prose ? 5 : 2)
                        .foregroundStyle(dark ? Tokens.ink : Color(hex: 0x657158))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 13)
        }
    }
}

private struct SolLine: View {
    let time: String
    let suffix: String
    let label: String
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(time).font(Fonts.fraunces(22, weight: .bold, italic: true)).foregroundStyle(Tokens.inkDeep)
                Text(suffix).font(Fonts.fraunces(12, weight: .regular)).foregroundStyle(Ochre.label)
            }
            Text(label).font(Fonts.inter(13)).foregroundStyle(Tokens.sageText)
        }
    }
}

private struct Fact: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            EyebrowLine(label, color: Tokens.sageText, size: 10, tracking: 1.6)
            Text(value).font(Fonts.fraunces(16, weight: .semibold)).foregroundStyle(Tokens.inkDeep)
        }
    }
}

private struct VPill: View {
    let label: String
    var ghost = false
    var tag = ""
    let action: () -> Void
    var body: some View {
        Text(label)
            .font(Fonts.inter(13, weight: .semibold))
            .foregroundStyle(ghost ? Tokens.forest : Tokens.cream)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(ghost ? Color.clear : Tokens.forest))
            .overlay(Capsule().stroke(ghost ? Tokens.sageA(0.3) : Tokens.forest, lineWidth: 1))
            .pressable(scale: 0.97, tag: tag, action: action)
    }
}

private struct Compass: View {
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 - 14
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle().stroke(Tokens.sageA(0.25), lineWidth: 1).frame(width: r * 2, height: r * 2).position(c)
                Circle().stroke(Tokens.sageA(0.12), lineWidth: 1).frame(width: r * 1.2, height: r * 1.2).position(c)
                Path { p in p.move(to: CGPoint(x: c.x, y: c.y - r)); p.addLine(to: CGPoint(x: c.x, y: c.y + r)) }.stroke(Tokens.sageA(0.3), lineWidth: 1)
                Path { p in p.move(to: CGPoint(x: c.x - r, y: c.y)); p.addLine(to: CGPoint(x: c.x + r, y: c.y)) }.stroke(Tokens.sageA(0.3), lineWidth: 1)
                Circle().fill(Ochre.numeral).frame(width: 12, height: 12).position(c)
                Text("N").font(Fonts.inter(11, weight: .bold)).foregroundStyle(Tokens.sageText).position(x: c.x, y: 6)
                Text("S").font(Fonts.inter(11, weight: .bold)).foregroundStyle(Tokens.sageText).position(x: c.x, y: geo.size.height - 6)
                Text("E").font(Fonts.inter(11, weight: .bold)).foregroundStyle(Tokens.sageText).position(x: geo.size.width - 6, y: c.y)
                Text("O").font(Fonts.inter(11, weight: .bold)).foregroundStyle(Tokens.sageText).position(x: 6, y: c.y)
            }
        }
    }
}
