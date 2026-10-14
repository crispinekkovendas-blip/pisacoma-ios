import SwiftUI

// site quien/index.tsx constants
private let segmentColors: [Color] = [0x1E3A5F, 0xC9963B, 0x2D5A8E, 0x0D1117, 0x5C2B1E, 0x1B5E3B].map { Color(hex: $0) }
private let defaultNames = ["Hermano 1", "Hermana 1", "Hermano 2", "Hermana 2", "Hermano 3", "Hermana 3", "Hermano 4", "Hermana 4"]
private let spinSeconds = 4.5
private let turns = 6.0
private let bg = Tokens.bg
private let gold = Tokens.accent
private let goldLight = Tokens.accentLight

/// The site's /quien: name wheel («Ruleta») and the table pointer («Apuntador»), dark theme.
struct WheelView: View {
    @State private var names: [String] = defaultNames
    @State private var input = ""
    @State private var mode = "wheel"
    @State private var angle: Double = 0
    @State private var spinning = false
    @State private var winner: String? = nil

    private func addNames() {
        let parts = input.split(whereSeparator: { $0 == "," || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !parts.isEmpty { names.append(contentsOf: parts); input = "" }
    }

    private func spin() {
        let n = names.count
        if n < 2 || spinning { return }
        winner = nil
        let seg = 360.0 / Double(n)
        let idx = Int.random(in: 0..<n)
        let targetMod = (((-(Double(idx) * seg + seg / 2)).truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let currentMod = ((angle.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let delta = (targetMod - currentMod + 360).truncatingRemainder(dividingBy: 360)
        spinning = true
        withAnimation(.timingCurve(0.17, 0.67, 0.32, 1, duration: spinSeconds)) { angle += turns * 360 + delta }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(spinSeconds * 1_000_000_000) + 50_000_000)
            spinning = false
            winner = idx < names.count ? names[idx] : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)
                Text("DINÁMICA").font(Fonts.inter(11, weight: .bold)).tracking(2.4).foregroundStyle(gold)
                Spacer().frame(height: 12)
                (Text("¿").foregroundColor(.white) + Text("Quién").foregroundColor(goldLight) + Text("?").foregroundColor(.white)).font(Fonts.playfair(44, weight: .bold))
                Spacer().frame(height: 12)
                Text("Para Escuela Sabática, oraciones, lecturas y juegos. Elige al azar desde una lista o pon el celular en la mesa y deja que la flecha señale a alguien.")
                    .font(Fonts.inter(15)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 22)
                HStack(spacing: 0) {
                    ForEach([("wheel", "Ruleta"), ("pointer", "Apuntador")], id: \.0) { id, label in
                        let active = mode == id
                        Text(label).font(Fonts.inter(14, weight: .semibold)).foregroundStyle(active ? bg : Color.white.opacity(0.7))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 9).fill(active ? gold : Color.clear))
                            .pressable(scale: 0.98, tag: "mode-\(id)") { mode = id }
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x161B22)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.border, lineWidth: 1))
                Spacer().frame(height: 26)
                if mode == "wheel" { wheelMode } else { PointerMode() }
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
            SiteFooter()
        }
        .background(bg)
        .uiId("quien-page")
    }

    private var wheelMode: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                WheelCanvas(names: names).rotationEffect(.degrees(angle))
                PointerTriangle().frame(width: 44, height: 52)
                if names.isEmpty { Text("Agrega nombres").font(Fonts.inter(20, weight: .semibold)).foregroundStyle(Color.white.opacity(0.45)).frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("wheel-empty") }
                if names.count == 1 { Text(names[0]).font(Fonts.inter(22, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("wheel-single") }
            }
            .aspectRatio(1, contentMode: .fit)
            .uiId("wheel-segments-\(names.count)")
            Spacer().frame(height: 18)
            Text(spinning ? "Girando..." : "GIRAR").font(Fonts.inter(17, weight: .bold)).tracking(2).foregroundStyle(bg)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [gold, goldLight], startPoint: .leading, endPoint: .trailing)))
                .opacity(spinning || names.count < 2 ? 0.5 : 1)
                .pressable(scale: 0.97, enabled: !spinning && names.count >= 2, tag: "wheel-spin") { spin() }
            if let w = winner, !spinning {
                Spacer().frame(height: 18)
                VStack(spacing: 4) {
                    Text("LE TOCA A").font(Fonts.inter(11)).tracking(2).foregroundStyle(gold)
                    Text(w).font(Fonts.playfair(30, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(18)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x161B22)))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold, lineWidth: 1))
                .uiId("wheel-winner")
            }
            Spacer().frame(height: 30)
            HStack {
                Text("Participantes ").font(Fonts.playfair(20, weight: .semibold)).foregroundStyle(.white)
                Text("(\(names.count))").font(Fonts.inter(14)).foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                if !names.isEmpty { Text("Limpiar").font(Fonts.inter(12, weight: .semibold)).foregroundStyle(Color(hex: 0xE65B5B)).pressable(scale: 0.97, tag: "wheel-clear") { names.removeAll(); winner = nil } }
            }
            Spacer().frame(height: 12)
            HStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    if input.isEmpty { Text("Nombre o lista (separados por coma)").font(Fonts.inter(14)).foregroundStyle(Color.white.opacity(0.4)) }
                    TextField("", text: $input).font(Fonts.inter(14)).foregroundStyle(.white).tint(gold).submitLabel(.done).onSubmit(addNames).autocorrectionDisabled().uiId("wheel-input")
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: 0x161B22)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tokens.border, lineWidth: 1))
                Text("+").font(Fonts.inter(22, weight: .bold)).foregroundStyle(bg).frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(gold))
                    .opacity(input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    .pressable(scale: 0.95, enabled: !input.trimmingCharacters(in: .whitespaces).isEmpty, tag: "wheel-add") { addNames() }
            }
            Spacer().frame(height: 12)
            if names.isEmpty { Text("Agrega al menos 2 nombres para girar la ruleta.").font(Fonts.inter(13)).foregroundStyle(Color.white.opacity(0.5)) }
            FlowLayout(spacing: 8) {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    HStack(spacing: 8) {
                        Circle().fill(segmentColors[i % segmentColors.count]).frame(width: 8, height: 8)
                        Text(name).font(Fonts.inter(13.5)).foregroundStyle(.white)
                        Text("×").font(Fonts.inter(15)).foregroundStyle(Color.white.opacity(0.6)).frame(width: 22, height: 22).pressable(tag: "wheel-remove-\(name)") { if i < names.count { names.remove(at: i) } }
                    }
                    .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: 0x161B22)))
                    .overlay(Capsule().stroke(Tokens.border, lineWidth: 1))
                    .uiId("wheel-name-\(name)")
                }
            }
            Spacer().frame(height: 14)
            Text("Tip · pega una lista separada por comas o saltos de línea y presiona Enter.").font(Fonts.inter(12.5)).lineSpacing(4).foregroundStyle(Color.white.opacity(0.5))
        }
    }
}

/// The wheel: one coloured segment per name with its label rotated into the segment, as the site draws it.
private struct WheelCanvas: View {
    let names: [String]
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 * 0.91
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r - 5, y: c.y - r - 5, width: 2 * (r + 5), height: 2 * (r + 5))), with: .color(bg))
            let n = names.count
            if n == 0 {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(hex: 0x1F2630)))
            } else if n == 1 {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(segmentColors[0]))
            } else {
                let seg = 360.0 / Double(n)
                for i in 0..<n {
                    let start = Angle.degrees(Double(i) * seg - 90)
                    let end = Angle.degrees(Double(i + 1) * seg - 90)
                    var p = Path()
                    p.move(to: c)
                    p.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
                    p.closeSubpath()
                    ctx.fill(p, with: .color(segmentColors[i % segmentColors.count]))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.85)), lineWidth: 1.5)
                }
                let fs = max(9.0, min(20.0, 220.0 / Double(n)))
                let maxChars = max(6, Int(34.0 / sqrt(Double(n))))
                for (i, name) in names.enumerated() {
                    let mid = Double(i) * seg - 90 + seg / 2
                    let mr = mid * .pi / 180
                    let tx = c.x + r * 0.62 * cos(mr)
                    let ty = c.y + r * 0.62 * sin(mr)
                    let display = name.count > maxChars ? String(name.prefix(maxChars - 1)) + "…" : name
                    var layer = ctx
                    layer.translateBy(x: tx, y: ty)
                    layer.rotate(by: .degrees(mid + 90))
                    layer.draw(Text(display).font(Fonts.inter(fs * 0.75, weight: .bold)).foregroundColor(.white), at: .zero, anchor: .center)
                }
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 15.6, y: c.y - 15.6, width: 31.2, height: 31.2)), with: .color(gold))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4.8, y: c.y - 4.8, width: 9.6, height: 9.6)), with: .color(bg))
        }
    }
}

private struct PointerTriangle: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: size.width / 2, y: size.height))
            p.addLine(to: CGPoint(x: 4, y: 4))
            p.addLine(to: CGPoint(x: size.width - 4, y: 4))
            p.closeSubpath()
            ctx.fill(p, with: .color(goldLight))
            ctx.stroke(p, with: .color(bg), lineWidth: 2)
        }
    }
}

/// «Apuntador»: a needle that spins on the dial and stops pointing at someone around the table (site pointer mode, same friction model).
private struct PointerMode: View {
    @State private var angle: Double = 0
    @State private var spinning = false
    @State private var settled = false

    private func spin() {
        if spinning { return }
        spinning = true; settled = false
        Task {
            // ω0 1200–1700 °/s with friction e^(−0.42·t) until 18 °/s, as the site integrates it
            var omega = 1200.0 + Double.random(in: 0..<500)
            var a = angle
            let dt = 1.0 / 60.0
            while omega > 18 {
                a += omega * dt
                omega *= exp(-0.42 * dt) - 0.0035 * dt * 60
                angle = a
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            spinning = false; settled = true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2 * 0.91
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r - 8, y: c.y - r - 8, width: 2 * (r + 8), height: 2 * (r + 8))), with: .color(bg))
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r - 2, y: c.y - r - 2, width: 2 * (r + 2), height: 2 * (r + 2))), with: .color(gold.opacity(0.55)), lineWidth: 1.5)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .radialGradient(Gradient(colors: [Color(hex: 0x1C2530), Color(hex: 0x141A23), bg]), center: c, startRadius: 0, endRadius: r))
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Tokens.border), lineWidth: 1)
                for i in 0..<24 {
                    let t = Double(i) * 15 * .pi / 180
                    let p = CGPoint(x: c.x + (r - 10) * cos(t), y: c.y + (r - 10) * sin(t))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(gold.opacity(0.7)))
                }
                var layer = ctx
                layer.translateBy(x: c.x, y: c.y)
                layer.rotate(by: .degrees(angle))
                layer.translateBy(x: -c.x, y: -c.y)
                var shaft = Path()
                shaft.move(to: CGPoint(x: c.x - 9, y: c.y - r * 0.55)); shaft.addLine(to: CGPoint(x: c.x + 9, y: c.y - r * 0.55)); shaft.addLine(to: CGPoint(x: c.x + 10, y: c.y - 8)); shaft.addLine(to: CGPoint(x: c.x - 10, y: c.y - 8)); shaft.closeSubpath()
                layer.fill(shaft, with: .linearGradient(Gradient(colors: [Color(hex: 0x7A5818), Color(hex: 0xF0C870), Color(hex: 0x7A5818)]), startPoint: CGPoint(x: c.x - 10, y: c.y), endPoint: CGPoint(x: c.x + 10, y: c.y)))
                var head = Path()
                head.move(to: CGPoint(x: c.x - 13, y: c.y - r * 0.55)); head.addLine(to: CGPoint(x: c.x, y: c.y - r * 0.95)); head.addLine(to: CGPoint(x: c.x + 13, y: c.y - r * 0.55)); head.closeSubpath()
                layer.fill(head, with: .linearGradient(Gradient(colors: [Color(hex: 0xF4CD80), gold, Color(hex: 0x7A5818)]), startPoint: CGPoint(x: c.x, y: c.y - r * 0.95), endPoint: CGPoint(x: c.x, y: c.y - r * 0.55)))
                var tail = Path()
                tail.move(to: CGPoint(x: c.x, y: c.y + 70)); tail.addLine(to: CGPoint(x: c.x - 10, y: c.y + 35)); tail.addLine(to: CGPoint(x: c.x + 10, y: c.y + 35)); tail.closeSubpath()
                layer.fill(tail, with: .color(gold.opacity(0.85)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 14, y: c.y - 14, width: 28, height: 28)), with: .color(gold))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10)), with: .color(bg))
            }
            .aspectRatio(1, contentMode: .fit)
            Spacer().frame(height: 18)
            Text(spinning ? "Girando..." : "GIRAR").font(Fonts.inter(17, weight: .bold)).tracking(2).foregroundStyle(bg)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [gold, goldLight], startPoint: .leading, endPoint: .trailing)))
                .opacity(spinning ? 0.5 : 1)
                .pressable(scale: 0.97, enabled: !spinning, tag: "pointer-spin") { spin() }
            Spacer().frame(height: 12)
            Text(spinning ? "..." : (settled ? "🎯 Le toca a quien señale la flecha" : "Pon el celular plano en la mesa y toca GIRAR"))
                .font(Fonts.inter(14)).foregroundStyle(settled ? goldLight : Color.white.opacity(0.6)).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            Spacer().frame(height: 30)
            Text("Cómo usarla").font(Fonts.playfair(20, weight: .semibold)).foregroundStyle(.white)
            Spacer().frame(height: 10)
            ForEach(Array([
                "Pongan el celular plano en el centro de la mesa, con la pantalla hacia arriba.",
                "Siéntense alrededor — cada persona en su posición.",
                "Toquen GIRAR. La flecha gira y se detiene apuntando hacia afuera.",
                "A quien le señale la punta — ¡le toca!",
            ].enumerated()), id: \.offset) { i, t in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1).").font(Fonts.inter(14, weight: .bold)).foregroundStyle(goldLight)
                    Text(t).font(Fonts.inter(14)).lineSpacing(5).foregroundStyle(Color.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 8)
            }
            Spacer().frame(height: 10)
            Text("Modo Apuntador · este modo no necesita lista de nombres, solo personas físicas alrededor del celular.").font(Fonts.inter(12.5)).lineSpacing(4).foregroundStyle(Color.white.opacity(0.5))
        }
    }
}
