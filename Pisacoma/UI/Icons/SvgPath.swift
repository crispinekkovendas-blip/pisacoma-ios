import SwiftUI

/// A small SVG path-data parser (M L H V C S Q T A Z, absolute and relative) → CGPath.
enum SvgPath {
    static func path(_ d: String) -> Path {
        var p = Path()
        var tokens = tokenize(d)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var lastCtrl: CGPoint? = nil
        var lastCmd: Character = "M"

        func next() -> CGFloat { defer { i += 1 }; return i < tokens.count ? (CGFloat(tokens[i].number ?? 0)) : 0 }
        func hasNumber() -> Bool { i < tokens.count && tokens[i].number != nil }
        /// Arc flags may be glued to the next number ("001 1" = large 0, sweep 0, x 1): one character each.
        func nextFlag() -> Bool {
            guard i < tokens.count, tokens[i].command == nil else { return false }
            let raw = tokens[i].raw
            if raw.count > 1 {
                let flag = raw.first == "1"
                tokens[i] = Token(command: nil, raw: String(raw.dropFirst()))
                return flag
            }
            i += 1
            return raw == "1"
        }

        while i < tokens.count {
            if let c = tokens[i].command { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let u = Character(cmd.uppercased())
            switch u {
            case "M":
                let x = next(), y = next()
                cur = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.move(to: cur); start = cur
                cmd = rel ? "l" : "L"
                lastCtrl = nil
            case "L":
                let x = next(), y = next()
                cur = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addLine(to: cur); lastCtrl = nil
            case "H":
                let x = next()
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                p.addLine(to: cur); lastCtrl = nil
            case "V":
                let y = next()
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                p.addLine(to: cur); lastCtrl = nil
            case "C":
                let x1 = next(), y1 = next(), x2 = next(), y2 = next(), x = next(), y = next()
                let c1 = rel ? CGPoint(x: cur.x + x1, y: cur.y + y1) : CGPoint(x: x1, y: y1)
                let c2 = rel ? CGPoint(x: cur.x + x2, y: cur.y + y2) : CGPoint(x: x2, y: y2)
                let end = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addCurve(to: end, control1: c1, control2: c2)
                lastCtrl = c2; cur = end
            case "S":
                let x2 = next(), y2 = next(), x = next(), y = next()
                let c1: CGPoint
                if let lc = lastCtrl, "CcSs".contains(lastCmd) { c1 = CGPoint(x: 2 * cur.x - lc.x, y: 2 * cur.y - lc.y) } else { c1 = cur }
                let c2 = rel ? CGPoint(x: cur.x + x2, y: cur.y + y2) : CGPoint(x: x2, y: y2)
                let end = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addCurve(to: end, control1: c1, control2: c2)
                lastCtrl = c2; cur = end
            case "Q":
                let x1 = next(), y1 = next(), x = next(), y = next()
                let c = rel ? CGPoint(x: cur.x + x1, y: cur.y + y1) : CGPoint(x: x1, y: y1)
                let end = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addQuadCurve(to: end, control: c)
                lastCtrl = c; cur = end
            case "T":
                let x = next(), y = next()
                let c: CGPoint
                if let lc = lastCtrl, "QqTt".contains(lastCmd) { c = CGPoint(x: 2 * cur.x - lc.x, y: 2 * cur.y - lc.y) } else { c = cur }
                let end = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                p.addQuadCurve(to: end, control: c)
                lastCtrl = c; cur = end
            case "A":
                let rx = next(), ry = next(), rot = next()
                let large = nextFlag(), sweep = nextFlag()
                let x = next(), y = next()
                let end = rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
                arc(&p, from: cur, to: end, rx: rx, ry: ry, rotation: rot, largeArc: large, sweep: sweep)
                cur = end; lastCtrl = nil
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil
            default:
                i += 1
            }
            lastCmd = cmd
            if u == "Z" { if i < tokens.count, tokens[i].command == nil { cmd = "L" } }
            if !hasNumber(), i < tokens.count, tokens[i].command == nil { i += 1 }
        }
        return p
    }

    private struct Token {
        let command: Character?
        let raw: String
        var number: Double? { command == nil ? Double(raw) : nil }
    }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        var num = ""
        func flush() {
            if !num.isEmpty { out.append(Token(command: nil, raw: num)); num = "" }
        }
        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" {
                flush(); out.append(Token(command: ch, raw: String(ch)))
            } else if ch == "-" || ch == "+" {
                if !num.isEmpty && !num.hasSuffix("e") && !num.hasSuffix("E") { flush() }
                num.append(ch)
            } else if ch == "." {
                if num.contains(".") && !num.lowercased().contains("e") { flush() }
                num.append(ch)
            } else if ch == "," || ch == " " || ch == "\n" || ch == "\t" || ch == "\r" {
                flush()
            } else {
                num.append(ch)
            }
        }
        flush()
        return out
    }

    /// SVG endpoint arc → center parameterisation → cubic Béziers (W3C implementation notes F.6).
    private static func arc(_ p: inout Path, from p0: CGPoint, to p1: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat, rotation: CGFloat, largeArc: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || p0 == p1 { p.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { lambda = sqrt(lambda); rx *= lambda; ry *= lambda }
        let num = max(0, rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p)
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den == 0 ? 0 : sqrt(num / den)
        if largeArc == sweep { coef = -coef }
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi } else if sweep && dTheta < 0 { dTheta += 2 * .pi }
        let segments = Int(ceil(abs(dTheta) / (.pi / 2)))
        let delta = dTheta / CGFloat(segments)
        let t = 4 / 3 * tan(delta / 4)
        var th = theta1
        for _ in 0..<segments {
            let cos1 = cos(th), sin1 = sin(th)
            let th2 = th + delta
            let cos2 = cos(th2), sin2 = sin(th2)
            func pt(_ c: CGFloat, _ s: CGFloat) -> CGPoint {
                CGPoint(x: cx + rx * cosPhi * c - ry * sinPhi * s, y: cy + rx * sinPhi * c + ry * cosPhi * s)
            }
            let e1 = pt(cos1, sin1)
            let e2 = pt(cos2, sin2)
            let d1 = CGPoint(x: -rx * cosPhi * sin1 - ry * sinPhi * cos1, y: -rx * sinPhi * sin1 + ry * cosPhi * cos1)
            let d2 = CGPoint(x: -rx * cosPhi * sin2 - ry * sinPhi * cos2, y: -rx * sinPhi * sin2 + ry * cosPhi * cos2)
            let c1 = CGPoint(x: e1.x + t * d1.x, y: e1.y + t * d1.y)
            let c2 = CGPoint(x: e2.x - t * d2.x, y: e2.y - t * d2.y)
            p.addCurve(to: e2, control1: c1, control2: c2)
            th = th2
        }
    }
}

/// One of the site's icons (Icons.all), tinted, scaled to fit the frame it is given.
struct IconView: View {
    let name: String
    var color: Color = .primary

    var body: some View {
        if let data = Icons.all[name] {
            GeometryReader { geo in
                let scale = min(geo.size.width / data.viewportWidth, geo.size.height / data.viewportHeight)
                let ox = (geo.size.width - data.viewportWidth * scale) / 2
                let oy = (geo.size.height - data.viewportHeight * scale) / 2
                ZStack {
                    ForEach(Array(data.paths.enumerated()), id: \.offset) { _, pd in
                        let path = SvgPath.path(pd.d)
                            .applying(CGAffineTransform(translationX: data.translateX, y: data.translateY))
                            .applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: ox, ty: oy))
                        if pd.fill { path.fill(color, style: FillStyle(eoFill: pd.evenOdd)) }
                        if pd.stroke {
                            path.stroke(color, style: StrokeStyle(lineWidth: pd.strokeWidth * scale, lineCap: pd.cap == "round" ? .round : (pd.cap == "square" ? .square : .butt), lineJoin: pd.join == "round" ? .round : (pd.join == "bevel" ? .bevel : .miter)))
                        }
                    }
                }
            }
        } else {
            Color.clear
        }
    }
}
