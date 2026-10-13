import CoreText
import SwiftUI
import UIKit

/// The site's families (Fraunces, Inter, DM Sans, Playfair Display), loaded from the variable
/// TTF files in `Fonts/` with CoreText so no PostScript name has to be known; the `wght`
/// axis gives every weight from one file, as on Android.
enum Fonts {
    private static let wghtAxis: Int = 0x77676874 // 'wght'
    private static var graphics: [String: CGFont] = [:]
    private static var cache: [String: CTFont] = [:]
    private static let lock = NSLock()

    private static func cgFont(_ file: String) -> CGFont? {
        if let f = graphics[file] { return f }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Fonts/\(file).ttf"),
              let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider) else { return nil }
        graphics[file] = font
        return font
    }

    /// A CTFont for `file` at `size` and CSS `weight` (100…900).
    static func ctFont(_ file: String, size: CGFloat, weight: Int) -> CTFont? {
        lock.lock(); defer { lock.unlock() }
        let key = "\(file)|\(size)|\(weight)"
        if let f = cache[key] { return f }
        guard let cg = cgFont(file) else { return nil }
        let base = CTFontCreateWithGraphicsFont(cg, size, nil, nil)
        let attrs: [CFString: Any] = [kCTFontVariationAttribute: [NSNumber(value: wghtAxis): NSNumber(value: weight)]]
        let desc = CTFontDescriptorCreateWithAttributes(attrs as CFDictionary)
        let font = CTFontCreateCopyWithAttributes(base, size, nil, desc)
        cache[key] = font
        return font
    }

    static func font(_ file: String, size: CGFloat, weight: Font.Weight) -> Font {
        if let ct = ctFont(file, size: size, weight: cssWeight(weight)) { return Font(ct) }
        return .system(size: size, weight: weight)
    }

    static func uiFont(_ file: String, size: CGFloat, weight: Font.Weight) -> UIFont {
        if let ct = ctFont(file, size: size, weight: cssWeight(weight)) { return ct as UIFont }
        return .systemFont(ofSize: size, weight: .regular)
    }

    static func cssWeight(_ w: Font.Weight) -> Int {
        switch w {
        case .ultraLight: return 200
        case .thin: return 200
        case .light: return 300
        case .regular: return 400
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy: return 800
        case .black: return 900
        default: return 400
        }
    }

    // ---- the families ----
    static func fraunces(_ size: CGFloat, weight: Font.Weight = .medium, italic: Bool = false) -> Font {
        font(italic ? "fraunces_italic" : "fraunces", size: size, weight: weight)
    }
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { font("inter", size: size, weight: weight) }
    static func dmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { font("dm_sans", size: size, weight: weight) }
    static func playfair(_ size: CGFloat, weight: Font.Weight = .bold) -> Font { font("playfair", size: size, weight: weight) }

    /// True when the bundled font files load (a unit test checks this).
    static func available(_ file: String) -> Bool { ctFont(file, size: 12, weight: 400) != nil }
}
