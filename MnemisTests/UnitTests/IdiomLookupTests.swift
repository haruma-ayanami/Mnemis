import Foundation
import Testing
@testable import Mnemis

/// Разбор статьи идиомы из Викисловаря (kaikki.org JSONL) и адрес статьи.
struct IdiomLookupTests {
    /// Сокращённая статья «break the ice» в формате kaikki: одна строка JSON на часть речи.
    private let fixture = """
    {"word": "break the ice", "pos": "verb", "senses": [{"glosses": ["To start to get to know people to avoid social awkwardness and formality."], "tags": ["idiomatic"], "examples": [{"text": "Including a few fun details can be a great way to break the ice."}]}, {"glosses": ["Used other than figuratively or idiomatically: see break, the, ice."]}], "translations": [{"lang_code": "ru", "word": "сде́лать пе́рвый шаг", "sense": "to start to get to know people"}, {"lang_code": "de", "word": "das Eis brechen"}, {"lang_code": "ru", "word": "положи́ть нача́ло"}]}
    {"word": "break", "pos": "verb", "senses": [{"glosses": ["To separate into pieces."]}]}
    """

    @Test func parsesRussianTranslationsDefinitionAndExample() throws {
        let entry = try #require(WiktionaryIdiomParser.parse(Data(fixture.utf8), phrase: "break the ice"))

        #expect(entry.translations == ["сделать первый шаг", "положить начало"])
        #expect(entry.definition == "To start to get to know people to avoid social awkwardness and formality")
        #expect(entry.example == "Including a few fun details can be a great way to break the ice.")
        #expect(entry.suggestedMeaning == "сделать первый шаг, положить начало")
    }

    @Test func fallsBackToEnglishDefinitionWithoutRussian() throws {
        let line = #"{"word": "hit the books", "pos": "verb", "senses": [{"glosses": ["To study, especially intensively."], "tags": ["idiomatic"]}]}"#

        let entry = try #require(WiktionaryIdiomParser.parse(Data(line.utf8), phrase: "hit the books"))

        #expect(entry.translations.isEmpty)
        #expect(entry.suggestedMeaning == "To study, especially intensively")
    }

    @Test func ignoresOtherHeadwordsAndBrokenLines() {
        let data = Data("not json\n{\"word\": \"break\", \"senses\": []}".utf8)

        #expect(WiktionaryIdiomParser.parse(data, phrase: "break the ice") == nil)
    }

    @Test func buildsKaikkiPathWithEncodedSpaces() throws {
        let url = try #require(WiktionaryIdiomProvider.url(for: "break the ice", baseURL: WiktionaryIdiomProvider.baseURL))

        #expect(url.absoluteString == "https://kaikki.org/dictionary/English/meaning/b/br/break%20the%20ice.jsonl")
    }
}
