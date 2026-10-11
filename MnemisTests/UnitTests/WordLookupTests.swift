import Foundation
import Testing
@testable import Mnemis

/// Разбор статьи слова из Викисловаря (kaikki.org JSONL).
struct WordLookupTests {
    private let fixture = """
    {"word": "diligent", "pos": "adj", "sounds": [{"ipa": "[ˈdɪlɪdʒənt]"}, {"ipa": "/ˈdɪlɪdʒənt/"}], "senses": [{"glosses": ["Showing care and effort in one's work."], "examples": [{"text": "She is a diligent student."}]}], "translations": [{"lang_code": "ru", "word": "приле́жный"}, {"lang_code": "ru", "word": "усе́рдный"}, {"lang_code": "de", "word": "fleißig"}, {"lang_code": "ru", "word": "diligent adj"}]}
    {"word": "diligent", "pos": "noun", "senses": [{"glosses": ["A diligent person."]}], "translations": [{"lang_code": "ru", "word": "труженик"}]}
    {"word": "diligent", "pos": "name", "senses": [{"glosses": ["A surname."]}]}
    {"word": "diligence", "pos": "noun", "senses": [{"glosses": ["Other article."]}]}
    """

    @Test func parsesSensesPerPartOfSpeechWithIPAAndExample() throws {
        let entry = try #require(WiktionaryWordParser.parse(Data(fixture.utf8), term: "diligent"))

        #expect(entry.ipa == "/ˈdɪlɪdʒənt/")
        #expect(entry.senses.map(\.partOfSpeech) == ["adjective", "noun"])
        let adjective = try #require(entry.sense(for: "adjective"))
        #expect(adjective.translations == ["прилежный", "усердный"])
        #expect(adjective.definition == "Showing care and effort in one's work")
        #expect(adjective.example == "She is a diligent student.")
    }

    @Test func skipsFormsOfOtherWordsAndUnknownParts() {
        let data = Data(#"{"word": "ran", "pos": "verb", "senses": [{"glosses": ["simple past of run"], "tags": ["form-of"]}]}"#.utf8)

        #expect(WiktionaryWordParser.parse(data, term: "ran") == nil)
    }

    @Test func fallsBackToFirstSenseForUnknownPart() throws {
        let entry = try #require(WiktionaryWordParser.parse(Data(fixture.utf8), term: "diligent"))

        #expect(entry.sense(for: "verb")?.partOfSpeech == "adjective")
    }
}

private struct StubWordLookup: WordLookupProvider {
    let entry: WordLookupEntry?
    func lookup(_ word: String) async throws -> WordLookupEntry? { entry }
}

private struct StubIdioms: IdiomProvider {
    let entry: IdiomEntry?
    func lookup(_ phrase: String) async throws -> IdiomEntry? { entry }
}

/// Три шага добавления: подстановка, правка и сохранение.
@MainActor
struct AddEntryFlowTests {
    private let entry = WordLookupEntry(lemma: "diligent", ipa: "/ˈdɪlɪdʒənt/", senses: [
        WordLookupSense(partOfSpeech: "adjective", translations: ["усердный", "прилежный"], definition: "Showing care", example: "She is a diligent student."),
        WordLookupSense(partOfSpeech: "noun", translations: ["труженик"], definition: "A diligent person", example: nil),
    ])

    @Test func lookupFillsFieldsAndPartOfSpeechSwitchesThem() async throws {
        let container = try AppContainer.inMemory(wordLookup: StubWordLookup(entry: entry))
        let model = AddEntryViewModel(container: container, kind: .word, text: "diligent")

        await model.search()

        #expect(model.lookup == .found)
        #expect(model.ipa == "/ˈdɪlɪdʒənt/")
        #expect(model.partOfSpeech == "adjective")
        #expect(model.translation == "усердный, прилежный")
        #expect(model.translationIsAuto)
        #expect(model.suggestion == "She is a diligent student.")

        model.select(partOfSpeech: "noun")
        #expect(model.translation == "труженик")
        #expect(model.definition == "A diligent person")
    }

    @Test func userEditsAreNotReplacedByLookup() async throws {
        let container = try AppContainer.inMemory(wordLookup: StubWordLookup(entry: entry))
        let model = AddEntryViewModel(container: container, kind: .word, text: "diligent")
        await model.search()
        model.translation = "старательный"

        model.select(partOfSpeech: "noun")

        #expect(model.translation == "старательный")
        #expect(!model.translationIsAuto)
    }

    @Test func savingCreatesTheWordWithAllDetails() async throws {
        let container = try AppContainer.inMemory(wordLookup: StubWordLookup(entry: entry))
        let model = AddEntryViewModel(container: container, kind: .word, text: "diligent")
        await model.search()
        model.selectLevel("B2")
        model.useSuggestion()

        let word = try model.save()

        let stored = try #require(try container.words.word(id: word.id))
        #expect(stored.translation == "усердный, прилежный")
        #expect(stored.partOfSpeech == "adjective")
        #expect(stored.level == "B2")
        #expect(stored.ipa == "/ˈdɪlɪdʒənt/")
        #expect(stored.definition == "Showing care")
        #expect(stored.licenseID == WiktionaryIdiomProvider.licenseID)
        #expect(try container.words.examples(forWordID: word.id).map(\.sentence) == ["She is a diligent student."])
    }

    @Test func notFoundLeavesFieldsForTheUser() async throws {
        let container = try AppContainer.inMemory(wordLookup: StubWordLookup(entry: nil))
        let model = AddEntryViewModel(container: container, kind: .word, text: "blorptastic")

        await model.search()

        #expect(model.lookup == .notFound)
        #expect(model.canContinue)
        #expect(model.translation.isEmpty)
    }

    @Test func existingWordBlocksTheFlowAndPointsAtIt() throws {
        let container = try AppContainer.inMemory()
        let existing = try container.wordEditor.addWord(lemma: "serendipity", translation: "")
        let model = AddEntryViewModel(container: container, kind: .word, text: " Serendipity ")

        #expect(model.existing?.id == existing.id)
        #expect(!model.canContinue)
    }

    @Test func idiomNeedsMeaningBeforeLeavingDetails() async throws {
        let idiom = IdiomEntry(text: "break the ice", translations: ["начать разговор"], definition: "To start talking", example: "A joke helped break the ice.")
        let container = try AppContainer.inMemory(idioms: StubIdioms(entry: idiom))
        let model = AddEntryViewModel(container: container, kind: .idiom, text: "break the ice")
        await model.search()
        model.next()
        #expect(model.step == .details)
        #expect(model.translation == "начать разговор")

        model.translation = ""
        #expect(!model.canContinue)
        model.translation = "начать разговор"
        model.selectLevel("B1")
        model.next()
        let word = try model.save()

        #expect(model.isLastStep)
        let stored = try #require(try container.words.word(id: word.id))
        #expect(stored.isIdiom)
        #expect(stored.level == "B1")
        #expect(stored.definition == "To start talking")
    }

    @Test func editedFieldsLoseTheAutoMark() throws {
        let container = try AppContainer.inMemory()
        var word = Word(lemma: "book", translation: "книга", ipa: "/bʊk/", licenseID: "wiktionary-kaikki", createdAt: Date())
        word.origin = .api
        container.words.insert(word)
        try container.persistence.save()
        let details = WordDetailsViewModel(word: word, container: container, onChange: {})

        details.update(meanings: [WordMeaning(partOfSpeech: "", translation: "книга")], definition: "", ipa: "/bʊk/ edited", level: "A2")

        let stored = try #require(try container.words.word(id: word.id))
        #expect(stored.editedFields == [Word.editedIPA])
        #expect(stored.level == "A2")
    }
}
