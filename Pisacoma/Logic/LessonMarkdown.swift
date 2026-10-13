import Foundation

/// Inline text with style ranges and Bible-reference annotations (the Android AnnotatedString).
struct Inline: Equatable {
    struct Span: Equatable { let start: Int; let end: Int; let bold: Bool }
    /// A reference span: `key` = `book|ch:from-to[;…]` (LessonMarkdown.refKey).
    struct Ref: Equatable { let start: Int; let end: Int; let key: String }
    let text: String
    let spans: [Span]
    let refs: [Ref]

    static func plain(_ s: String) -> Inline { Inline(text: s, spans: [], refs: []) }
}

/// One rendered block of a lesson day (the subset of Markdown the quarterly uses).
enum MdBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(Inline)
    /// A `> ` block; the site's quarterly starts it with `<p>Para memorizar</p>` as a label.
    case quote(label: String?, text: Inline)
    /// The study question the quarterly writes between backticks (site `.es-prompt`).
    case prompt(Inline)
    case bullet(Inline)
    case rule

    var kind: String {
        switch self {
        case .heading: return "Heading"
        case .paragraph: return "Paragraph"
        case .quote: return "Quote"
        case .prompt: return "Prompt"
        case .bullet: return "Bullet"
        case .rule: return "Rule"
        }
    }
}

/**
 The site's lesson pipeline ([leccion]/index.tsx): front matter → day title, short backtick
 spans → prompt boxes, marked (gfm) for the rest, Bible references wrapped as tappable spans.
 */
enum LessonMarkdown {
    struct Day: Equatable { let title: String; let body: String }

    private static let front = try! NSRegularExpression(pattern: "^---\\s*\\n([\\s\\S]*?)\\n---\\s*\\n?([\\s\\S]*)$")
    private static let titleRe = try! NSRegularExpression(pattern: "^title:\\s*(.+)$", options: [.anchorsMatchLines])

    static func parseDay(_ raw: String) -> Day {
        let ns = raw as NSString
        guard let m = front.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)) else { return Day(title: "", body: raw) }
        let fm = ns.substring(with: m.range(at: 1))
        var title = ""
        if let t = titleRe.firstMatch(in: fm, range: NSRange(location: 0, length: (fm as NSString).length)) {
            title = (fm as NSString).substring(with: t.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
        return Day(title: title, body: ns.substring(with: m.range(at: 2)))
    }

    static func refKey(_ ref: ParsedRef) -> String {
        "\(ref.bookNum)|" + ref.sections.map { "\($0.chapter):\($0.from)-\($0.to)" }.joined(separator: ";")
    }

    static func decodeRef(_ key: String) -> (Int, [RefSection]) {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return (0, []) }
        let sections = parts[1].split(separator: ";").compactMap { s -> RefSection? in
            let cs = s.split(separator: ":", maxSplits: 1)
            guard cs.count == 2 else { return nil }
            let span = cs[1].split(separator: "-", maxSplits: 1)
            guard span.count == 2, let ch = Int(cs[0]), let from = Int(span[0]), let to = Int(span[1]) else { return nil }
            return RefSection(chapter: ch, from: from, to: to)
        }
        return (Int(parts[0]) ?? 0, sections)
    }

    private static let promptRe = try! NSRegularExpression(pattern: "`([^`\\n][^`]*)`")
    private static let promptMark = "\u{0001}PROMPT\u{0001}"

    static func parse(_ body: String) -> [MdBlock] {
        // Short backtick spans become their own block, like the site's preprocess().
        let ns = body as NSString
        var text = ""
        var last = 0
        for m in promptRe.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
            text += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let inner = ns.substring(with: m.range(at: 1))
            if inner.count < 200 { text += "\n\n\(promptMark)\(inner.trimmingCharacters(in: .whitespaces))\(promptMark)\n\n" } else { text += ns.substring(with: m.range) }
            last = m.range.location + m.range.length
        }
        text += ns.substring(from: last)

        var blocks: [MdBlock] = []
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var i = 0
        var para = ""
        func flushPara() {
            let p = para.trimmingCharacters(in: .whitespaces)
            para = ""
            if p.isEmpty { return }
            if p.hasPrefix(promptMark) && p.hasSuffix(promptMark) && p.count >= promptMark.count * 2 {
                let inner = String(p.dropFirst(promptMark.count).dropLast(promptMark.count))
                blocks.append(.prompt(inline(inner)))
            } else {
                blocks.append(.paragraph(inline(p)))
            }
        }
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty { flushPara(); i += 1 }
            else if t == "---" || t == "***" { flushPara(); blocks.append(.rule); i += 1 }
            else if t.hasPrefix("#") {
                flushPara()
                let level = min(max(t.prefix { $0 == "#" }.count, 1), 6)
                blocks.append(.heading(level: level, text: stripTags(String(t.dropFirst(level)).trimmingCharacters(in: .whitespaces))))
                i += 1
            } else if t.hasPrefix(">") {
                flushPara()
                var quoteLines: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quoteLines.append(String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                var label: String? = nil
                var bodyLines = quoteLines
                if let first = quoteLines.first, first.hasPrefix("<p>"), first.hasSuffix("</p>") {
                    label = String(first.dropFirst(3).dropLast(4)).trimmingCharacters(in: .whitespaces)
                    bodyLines = Array(quoteLines.dropFirst())
                }
                blocks.append(.quote(label: label, text: inline(bodyLines.joined(separator: " ").trimmingCharacters(in: .whitespaces))))
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                flushPara()
                blocks.append(.bullet(inline(String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces))))
                i += 1
            } else {
                if !para.isEmpty { para += " " }
                para += t
                i += 1
            }
        }
        flushPara()
        return blocks
    }

    private static let tagRe = try! NSRegularExpression(pattern: "<[^>]+>")
    static func stripTags(_ s: String) -> String {
        tagRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "")
    }

    private static let boldRe = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let italicRe = try! NSRegularExpression(pattern: "(?<![*\\w])\\*(?!\\*)(.+?)\\*(?!\\*)|(?<!\\w)_(.+?)_(?!\\w)")

    /// Inline markdown (bold, italic, `<br>`, tags stripped) plus Bible-reference annotations.
    static func inline(_ src: String) -> Inline {
        var s = src.replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "<br/>", with: "\n").replacingOccurrences(of: "<br />", with: "\n")
        s = stripTags(s).replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
        let ns = s as NSString
        let all = NSRange(location: 0, length: ns.length)
        let matches = (boldRe.matches(in: s, range: all).map { ($0, true) } + italicRe.matches(in: s, range: all).map { ($0, false) })
            .sorted { $0.0.range.location < $1.0.range.location }
        var out = ""
        var spans: [Inline.Span] = []
        var last = 0
        for (m, bold) in matches {
            if m.range.location < last { continue }
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            var inner = ""
            for g in 1..<m.numberOfRanges {
                let r = m.range(at: g)
                if r.location != NSNotFound, r.length > 0 { inner = ns.substring(with: r); break }
            }
            let start = (out as NSString).length
            out += inner
            spans.append(Inline.Span(start: start, end: (out as NSString).length, bold: bold))
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        let refs = BibleRefs.findRefs(out).map { Inline.Ref(start: $0.start, end: $0.end, key: refKey($0)) }
        return Inline(text: out, spans: spans, refs: refs)
    }
}
