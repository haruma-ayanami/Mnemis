import Foundation
import Testing
@testable import Mnemis

/// Правка значений по частям речи и то, что сессия Learn видит правку сразу.
@MainActor
struct WordEditingTests {
    let clock = TestClock()

    private func book(in container: AppContainer) throws -> Word {
        let word = Word(lemma: "book", translation: "книга, книжка", partOfSpeech: "noun", meanings: [
            WordMeaning(partOfSpeech: "noun", translation: "книга, книжка"),
            WordMeaning(partOfSpeech: "verb", translation: "бронировать"),
        ], level: "A2", frequencyRank: 1, origin: .builtin, createdAt: clock.now)
        container.words.insert(word)
        try container.persistence.save()
        return word
    }

    @Test func clearingAMeaningRemovesIt() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try book(in: container)
        let details = WordDetailsViewModel(word: word, container: container, onChange: {})

        details.update(meanings: [
            WordMeaning(partOfSpeech: "noun", translation: "книга"),
            WordMeaning(partOfSpeech: "verb", translation: "  "),
        ], definition: "", ipa: "")

        let stored = try #require(try container.words.word(id: word.id))
        #expect(stored.translation == "книга")
        #expect(stored.meanings.isEmpty)
        #expect(stored.allMeanings.map(\.translation) == ["книга"])
    }

    @Test func runningSessionShowsTheEditedTranslation() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try book(in: container)
        let session = LearnViewModel(container: container)
        session.startIfNeeded()
        #expect(session.current?.id == word.id)

        var edited = word
        edited.translation = "книга"
        edited.meanings = []
        try container.wordEditor.update(edited)
        session.startIfNeeded()

        #expect(session.current?.translation == "книга")
        #expect(session.current?.meanings.isEmpty == true)
    }
}
