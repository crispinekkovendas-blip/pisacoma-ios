import XCTest
@testable import Pisacoma

/// The site's diccionario route: es.wiktionary.org REST definitions, `es` | `Spanish` | first language, the three messages.
final class WiktionaryTests: XCTestCase {
    private let body = "{\"es\":[{\"partOfSpeech\":\"Sustantivo femenino\",\"language\":\"Español\",\"definitions\":[{\"definition\":\"Don o favor que se hace <b>sin merecimiento</b>.\",\"examples\":[\"Por la gracia de Dios.\"]},{\"definition\":\"Perdón o indulto.\"}]},{\"partOfSpeech\":\"Interjección\",\"definitions\":[{\"definition\":\"Se usa para agradecer.\"}]}]}"

    func testUrlEncodesTheWord() {
        XCTAssertEqual(Wiktionary.url("sábado"), "https://es.wiktionary.org/api/rest_v1/page/definition/s%C3%A1bado")
    }

    func testParsesSpanishSections() {
        let sections = Wiktionary.parse(body)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].partOfSpeech, "Sustantivo femenino")
        XCTAssertEqual(sections[0].definitions.count, 2)
        XCTAssertEqual(sections[0].definitions[0].definition, "Don o favor que se hace sin merecimiento.")
        XCTAssertEqual(sections[0].definitions[0].examples, ["Por la gracia de Dios."])
        XCTAssertTrue(sections[1].definitions[0].examples.isEmpty)
    }

    func testFallsBackToFirstLanguage() {
        XCTAssertEqual(Wiktionary.parse("{\"Spanish\":[{\"partOfSpeech\":\"Verbo\",\"definitions\":[{\"definition\":\"x\"}]}]}")[0].partOfSpeech, "Verbo")
        XCTAssertEqual(Wiktionary.parse("{\"la\":[{\"partOfSpeech\":\"Nomen\",\"definitions\":[{\"definition\":\"y\"}]}]}")[0].partOfSpeech, "Nomen")
        XCTAssertTrue(Wiktionary.parse("{}").isEmpty)
        XCTAssertTrue(Wiktionary.parse("not json").isEmpty)
    }

    func testOutcomesMapToTheSitesMessages() {
        XCTAssertEqual(Wiktionary.notFoundMessage("fulano"), "«fulano» — no encontramos esta palabra en el Wiccionario en español.")
        XCTAssertEqual(Wiktionary.emptyMessage("x"), "«x» no tiene definiciones registradas.")
        XCTAssertEqual(Wiktionary.networkError, "Error de red. Intenta de nuevo.")
    }

    func testSuggestedWordsAreTheSites() {
        XCTAssertEqual(Array(Wiktionary.suggested.prefix(4)), ["amor", "fe", "esperanza", "gracia"])
        XCTAssertTrue(Wiktionary.suggested.contains("sábado"))
        XCTAssertEqual(Wiktionary.suggested.last, "fiel")
    }
}
