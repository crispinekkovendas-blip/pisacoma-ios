import XCTest
@testable import Pisacoma

/// The site's lesson pipeline: front matter → day title; a short `backtick` span → a prompt box;
/// the rest through marked (gfm); Bible references as tappable spans. The port keeps the same blocks.
final class LessonMarkdownTests: XCTestCase {
    private let day1 = """
    ---
    title:  El ministerio de Pablo en Corinto
    date:   27/06/2026
    ---

    ### Lee para el estudio de esta semana
    1 Corintios 1: 1; Gálatas 1: 1; Hechos 17: 16-34.

    > <p>Para memorizar</p>
    > «Entonces el Señor dijo a Pablo en una visión nocturna» (Hech. 18: 9-10).

    El gran misionero **William Carey** solía decir que reparaba zapatos (Hech. 18: 1-3).

    `Lee 1 Corintios 1: 1 y Romanos 1: 1. ¿Qué dos elementos destacan?`

    ---

    #### Comentarios Elena G.W

    Aunque Pablo se sentó como alumno.
    """

    func testFrontMatterGivesTheDayTitle() {
        let parsed = LessonMarkdown.parseDay(day1)
        XCTAssertEqual(parsed.title, "El ministerio de Pablo en Corinto")
        XCTAssertTrue(parsed.body.hasPrefix("### Lee para"))
    }

    func testNoFrontMatterKeepsTheBody() {
        let parsed = LessonMarkdown.parseDay("Hola")
        XCTAssertEqual(parsed.title, "")
        XCTAssertEqual(parsed.body, "Hola")
    }

    func testBlocksInOrder() {
        let blocks = LessonMarkdown.parse(LessonMarkdown.parseDay(day1).body)
        XCTAssertEqual(blocks.map(\.kind), ["Heading", "Paragraph", "Quote", "Paragraph", "Prompt", "Rule", "Heading", "Paragraph"])
        if case let .heading(level, text) = blocks[0] { XCTAssertEqual(level, 3); XCTAssertEqual(text, "Lee para el estudio de esta semana") } else { XCTFail() }
        if case let .heading(level, _) = blocks[6] { XCTAssertEqual(level, 4) } else { XCTFail() }
    }

    func testQuoteKeepsItsLabelAndText() {
        let blocks = LessonMarkdown.parse(LessonMarkdown.parseDay(day1).body)
        guard case let .quote(label, text) = blocks[2] else { return XCTFail() }
        XCTAssertEqual(label, "Para memorizar")
        XCTAssertTrue(text.text.hasPrefix("«Entonces el Señor"))
    }

    func testPromptIsTheBacktickQuestion() {
        let blocks = LessonMarkdown.parse(LessonMarkdown.parseDay(day1).body)
        guard case let .prompt(p) = blocks[4] else { return XCTFail() }
        XCTAssertEqual(p.text, "Lee 1 Corintios 1: 1 y Romanos 1: 1. ¿Qué dos elementos destacan?")
    }

    func testBibleReferencesAreAnnotated() {
        let blocks = LessonMarkdown.parse(LessonMarkdown.parseDay(day1).body)
        guard case let .paragraph(para) = blocks[1] else { return XCTFail() }
        XCTAssertEqual(para.refs.count, 3)
        XCTAssertEqual(para.refs[0].key, "46|1:1-1")
        XCTAssertEqual(para.refs[2].key, "44|17:16-34")
        guard case let .quote(_, quote) = blocks[2] else { return XCTFail() }
        XCTAssertEqual(quote.refs.map(\.key), ["44|18:9-10"])
    }

    func testBoldIsStyled() {
        let blocks = LessonMarkdown.parse(LessonMarkdown.parseDay(day1).body)
        guard case let .paragraph(para) = blocks[3] else { return XCTFail() }
        XCTAssertTrue(para.text.contains("William Carey"))
        XCTAssertTrue(para.spans.contains { $0.bold })
        XCTAssertFalse(para.text.contains("**"))
    }

    func testRefKeyRoundTrip() {
        let (book, sections) = LessonMarkdown.decodeRef("43|3:16-16;5:4-8")
        XCTAssertEqual(book, 43)
        XCTAssertEqual(sections, [RefSection(chapter: 3, from: 16, to: 16), RefSection(chapter: 5, from: 4, to: 8)])
    }
}
