import Foundation

/// A chapter:from-to span inside a reference (site bibleStore.ts RefSection).
struct RefSection: Equatable, Hashable {
    let chapter: Int
    let from: Int
    let to: Int
}

/// A reference found in free text (site bibleStore.ts ParsedRef). `start`/`end` are UTF-16 offsets.
struct ParsedRef: Equatable {
    let bookNum: Int
    let bookName: String
    let sections: [RefSection]
    let display: String
    let start: Int
    let end: Int
}

/**
 Port of the site's src/utils/bibleStore.ts findRefs: the same Spanish book map (full names,
 accents, abbreviations with and without a dot, numbered books), the same regex
 ("Juan 15:9", "1 Cor. 10:12 al 15", "Hechos 17: 16-34") and the same `; 5:4-8` continuations.
 */
enum BibleRefs {
    static let bookMap: [String: Int] = [
        "génesis": 1, "genesis": 1, "gén": 1, "gen": 1, "gén.": 1, "gen.": 1, "gn": 1,
        "éxodo": 2, "exodo": 2, "éxo": 2, "exo": 2, "éxo.": 2, "exo.": 2, "ex": 2,
        "levítico": 3, "levitico": 3, "lev": 3, "lev.": 3, "lv": 3,
        "números": 4, "numeros": 4, "núm": 4, "num": 4, "núm.": 4, "num.": 4, "nm": 4,
        "deuteronomio": 5, "deut": 5, "deut.": 5, "dt": 5,
        "josué": 6, "josue": 6, "jos": 6, "jos.": 6,
        "jueces": 7, "juec": 7, "juec.": 7, "jue": 7,
        "rut": 8, "rt": 8,
        "1 samuel": 9, "1 sam": 9, "1 sam.": 9, "1s": 9,
        "2 samuel": 10, "2 sam": 10, "2 sam.": 10, "2s": 10,
        "1 reyes": 11, "1 rey": 11, "1 rey.": 11, "1r": 11,
        "2 reyes": 12, "2 rey": 12, "2 rey.": 12, "2r": 12,
        "1 crónicas": 13, "1 cronicas": 13, "1 crón": 13, "1 cron": 13, "1 crón.": 13, "1 cron.": 13, "1cr": 13,
        "2 crónicas": 14, "2 cronicas": 14, "2 crón": 14, "2 cron": 14, "2 crón.": 14, "2 cron.": 14, "2cr": 14,
        "esdras": 15, "esd": 15, "esd.": 15,
        "nehemías": 16, "nehemias": 16, "neh": 16, "neh.": 16,
        "ester": 17, "est": 17,
        "job": 18,
        "salmos": 19, "salmo": 19, "sal": 19, "sal.": 19,
        "proverbios": 20, "prov": 20, "prov.": 20, "pr": 20,
        "eclesiastés": 21, "eclesiastes": 21, "ecl": 21, "ecl.": 21, "ec": 21,
        "cantares": 22, "cant": 22, "cant.": 22, "cnt": 22,
        "isaías": 23, "isaias": 23, "isa": 23, "isa.": 23, "is": 23,
        "jeremías": 24, "jeremias": 24, "jer": 24, "jer.": 24,
        "lamentaciones": 25, "lam": 25, "lam.": 25, "lm": 25,
        "ezequiel": 26, "eze": 26, "eze.": 26, "ez": 26,
        "daniel": 27, "dan": 27, "dan.": 27, "dn": 27,
        "oseas": 28, "ose": 28, "ose.": 28, "os": 28,
        "joel": 29, "jl": 29,
        "amós": 30, "amos": 30, "am": 30,
        "abdías": 31, "abdias": 31, "abd": 31,
        "jonás": 32, "jonas": 32, "jon": 32, "jon.": 32,
        "miqueas": 33, "miq": 33, "miq.": 33, "mi": 33,
        "nahúm": 34, "nahum": 34, "nah": 34, "nah.": 34,
        "habacuc": 35, "hab": 35, "hab.": 35,
        "sofonías": 36, "sofonias": 36, "sof": 36, "sof.": 36,
        "hageo": 37, "hag": 37, "hag.": 37,
        "zacarías": 38, "zacarias": 38, "zac": 38, "zac.": 38,
        "malaquías": 39, "malaquias": 39, "mal": 39, "mal.": 39,
        "mateo": 40, "mat": 40, "mat.": 40, "mt": 40,
        "marcos": 41, "mar": 41, "mar.": 41, "mc": 41, "mr": 41,
        "lucas": 42, "luc": 42, "luc.": 42, "lc": 42,
        "juan": 43, "jn": 43,
        "hechos": 44, "hech": 44, "hech.": 44, "hch": 44,
        "romanos": 45, "rom": 45, "rom.": 45, "ro": 45,
        "1 corintios": 46, "1 cor": 46, "1 cor.": 46, "1co": 46,
        "2 corintios": 47, "2 cor": 47, "2 cor.": 47, "2co": 47,
        "gálatas": 48, "galatas": 48, "gál": 48, "gal": 48, "gál.": 48, "gal.": 48, "gá": 48,
        "efesios": 49, "efe": 49, "efe.": 49, "ef": 49,
        "filipenses": 50, "fil": 50, "fil.": 50,
        "colosenses": 51, "col": 51, "col.": 51,
        "1 tesalonicenses": 52, "1 tes": 52, "1 tes.": 52, "1ts": 52,
        "2 tesalonicenses": 53, "2 tes": 53, "2 tes.": 53, "2ts": 53,
        "1 timoteo": 54, "1 tim": 54, "1 tim.": 54, "1ti": 54,
        "2 timoteo": 55, "2 tim": 55, "2 tim.": 55, "2ti": 55,
        "tito": 56, "tit": 56, "tit.": 56,
        "filemón": 57, "filemon": 57, "flm": 57,
        "hebreos": 58, "heb": 58, "heb.": 58, "hb": 58, "he": 58,
        "santiago": 59, "sant": 59, "sant.": 59, "stg": 59,
        "1 pedro": 60, "1 ped": 60, "1 ped.": 60, "1 pe": 60, "1p": 60,
        "2 pedro": 61, "2 ped": 61, "2 ped.": 61, "2 pe": 61, "2p": 61,
        "1 juan": 62, "1 jn": 62,
        "2 juan": 63, "2 jn": 63,
        "3 juan": 64, "3 jn": 64,
        "judas": 65, "jud": 65, "jud.": 65,
        "apocalipsis": 66, "apoc": 66, "apoc.": 66, "ap": 66,
    ]

    static let bookNames: [Int: String] = [
        1: "Génesis", 2: "Éxodo", 3: "Levítico", 4: "Números", 5: "Deuteronomio",
        6: "Josué", 7: "Jueces", 8: "Rut", 9: "1 Samuel", 10: "2 Samuel",
        11: "1 Reyes", 12: "2 Reyes", 13: "1 Crónicas", 14: "2 Crónicas",
        15: "Esdras", 16: "Nehemías", 17: "Ester", 18: "Job", 19: "Salmos",
        20: "Proverbios", 21: "Eclesiastés", 22: "Cantares", 23: "Isaías",
        24: "Jeremías", 25: "Lamentaciones", 26: "Ezequiel", 27: "Daniel",
        28: "Oseas", 29: "Joel", 30: "Amós", 31: "Abdías", 32: "Jonás",
        33: "Miqueas", 34: "Nahúm", 35: "Habacuc", 36: "Sofonías", 37: "Hageo",
        38: "Zacarías", 39: "Malaquías", 40: "Mateo", 41: "Marcos", 42: "Lucas",
        43: "Juan", 44: "Hechos", 45: "Romanos", 46: "1 Corintios", 47: "2 Corintios",
        48: "Gálatas", 49: "Efesios", 50: "Filipenses", 51: "Colosenses",
        52: "1 Tesalonicenses", 53: "2 Tesalonicenses", 54: "1 Timoteo", 55: "2 Timoteo",
        56: "Tito", 57: "Filemón", 58: "Hebreos", 59: "Santiago",
        60: "1 Pedro", 61: "2 Pedro", 62: "1 Juan", 63: "2 Juan", 64: "3 Juan",
        65: "Judas", 66: "Apocalipsis",
    ]

    /// Lowercased, accents removed, trimmed.
    static func fold(_ s: String) -> String {
        s.lowercased().folding(options: [.diacriticInsensitive], locale: Locale(identifier: "es")).trimmingCharacters(in: .whitespaces)
    }

    static func bookName(_ num: Int) -> String { bookNames[num] ?? "" }

    static func resolveBook(_ raw: String) -> Int? {
        let lo = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if let n = bookMap[lo] { return n }
        let stripped = fold(lo)
        for (k, v) in bookMap where fold(k) == stripped { return v }
        return nil
    }

    // (optional number prefix) BookName chapter:verse (optional "al/-/y endVerse")
    private static let refRe = try! NSRegularExpression(pattern: "(?:(\\d)\\s+)?([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\\.?)\\s+(\\d+)\\s*:\\s*(\\d+)(?:\\s*(?:al|-|–|y|,)\\s*(\\d+))?")
    private static let contRe = try! NSRegularExpression(pattern: "^\\s*;\\s*(\\d+)\\s*:\\s*(\\d+)(?:\\s*(?:al|-|–|y|,)\\s*(\\d+))?")

    static func findRefs(_ text: String) -> [ParsedRef] {
        let ns = text as NSString
        var refs: [ParsedRef] = []
        var searchFrom = 0
        while searchFrom <= ns.length, let m = refRe.firstMatch(in: text, range: NSRange(location: searchFrom, length: ns.length - searchFrom)) {
            func group(_ i: Int) -> String? { let r = m.range(at: i); return r.location == NSNotFound ? nil : ns.substring(with: r) }
            let numPrefix = group(1)
            let bookPart = group(2)!
            let rawBook = numPrefix != nil ? "\(numPrefix!) \(bookPart)" : bookPart
            var end = m.range.location + m.range.length
            if let bookNum = resolveBook(rawBook) {
                let from = Int(group(4)!)!
                var sections = [RefSection(chapter: Int(group(3)!)!, from: from, to: group(5).flatMap { Int($0) } ?? from)]
                var display = ns.substring(with: m.range).trimmingCharacters(in: .whitespaces)
                var rest = ns.substring(from: end)
                while let cont = contRe.firstMatch(in: rest, range: NSRange(location: 0, length: (rest as NSString).length)) {
                    let rs = rest as NSString
                    func cg(_ i: Int) -> String? { let r = cont.range(at: i); return r.location == NSNotFound ? nil : rs.substring(with: r) }
                    let cFrom = Int(cg(2)!)!
                    sections.append(RefSection(chapter: Int(cg(1)!)!, from: cFrom, to: cg(3).flatMap { Int($0) } ?? cFrom))
                    let contText = rs.substring(with: cont.range)
                    display = (display + contText).trimmingCharacters(in: .whitespaces)
                    end += cont.range.length
                    rest = ns.substring(from: end)
                }
                refs.append(ParsedRef(bookNum: bookNum, bookName: bookNames[bookNum] ?? rawBook, sections: sections, display: display, start: m.range.location, end: end))
            }
            searchFrom = end
        }
        return refs
    }
}
