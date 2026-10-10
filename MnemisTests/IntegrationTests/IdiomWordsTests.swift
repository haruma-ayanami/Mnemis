import Foundation
import SwiftData
import Testing
@testable import Mnemis

/// Идиомы — это слова с частью речи `idiom`: создание, разделы, прогресс, идиома дня и перенос из прежней таблицы.
@MainActor
struct IdiomWordsTests {
    let clock = TestClock()

    @Test func addedIdiomIsAWordWithUserExample() throws {
        let container = try AppContainer.inMemory(clock: clock)

        let idiom = try container.wordEditor.addIdiom(text: "  break the ice ", meaning: "разрядить обстановку", example: " A joke helped. ")

        let stored = try #require(try container.words.word(id: idiom.id))
        #expect(stored.isIdiom)
        #expect(stored.lemma == "break the ice")
        #expect(stored.translation == "разрядить обстановку")
        let examples = try container.words.examples(forWordID: idiom.id)
        #expect(examples.map(\.sentence) == ["A joke helped."])
        #expect(examples.first?.isUserCreated == true)
    }

    @Test func idiomsAndWordsAreListedSeparately() throws {
        let container = try AppContainer.inMemory(clock: clock)
        try container.wordEditor.addWord(lemma: "serendipity", translation: "счастливая случайность")
        try container.wordEditor.addIdiom(text: "break the ice", meaning: "разрядить обстановку")

        #expect(try container.words.page(offset: 0, limit: 10, kind: .words).map(\.lemma) == ["serendipity"])
        #expect(try container.words.page(offset: 0, limit: 10, kind: .idioms).map(\.lemma) == ["break the ice"])
        #expect(try container.words.count(kind: .words) == 1)
        #expect(try container.words.count(kind: .idioms) == 1)
        #expect(try container.words.search("ice", limit: 10, kind: .words).isEmpty)
        #expect(try container.words.search("ice", limit: 10, kind: .idioms).map(\.lemma) == ["break the ice"])
    }

    @Test func duplicateIdiomIsRejected() throws {
        let container = try AppContainer.inMemory(clock: clock)
        try container.wordEditor.addIdiom(text: "break the ice", meaning: "разрядить обстановку")

        #expect(throws: WordEditorError.self) {
            try container.wordEditor.addIdiom(text: "  Break the ICE ", meaning: "сделать первый шаг")
        }
        #expect(try container.words.count(kind: .idioms) == 1)
    }

    @Test func idiomGetsTheSameProgressAsAWord() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let idiom = try container.wordEditor.addIdiom(text: "hit the books", meaning: "зубрить")

        try container.wordStatus.markKnown(wordID: idiom.id)

        #expect(try container.progress.progress(forWordID: idiom.id)?.status == .known)
        #expect(try container.progress.count(status: .known) == 1)
    }

    @Test func idiomOfTheDayIsStableAndSkipsKnownIdioms() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let known = try container.wordEditor.addIdiom(text: "break the ice", meaning: "разрядить обстановку")
        let learning = try container.wordEditor.addIdiom(text: "hit the books", meaning: "зубрить")
        try container.wordStatus.markKnown(wordID: known.id)

        for day in ["2026-10-09", "2026-10-10", "2026-10-11"] {
            let picked = try container.dailyWordUseCase.idiomOfTheDay(dayID: day)
            #expect(picked?.id == learning.id)
            let again = try container.dailyWordUseCase.idiomOfTheDay(dayID: day)
            #expect(picked?.id == again?.id)
        }
    }

    @Test func dailyWordNeverPicksAnIdiom() throws {
        let container = try AppContainer.inMemory(clock: clock)
        try container.wordEditor.addIdiom(text: "break the ice", meaning: "разрядить обстановку")
        try container.wordEditor.addWord(lemma: "serendipity", translation: "счастливая случайность")

        let word = try container.dailyWordUseCase.todaysWord(preferredLevel: nil)

        #expect(word?.lemma == "serendipity")
    }

    @Test func deletingUserIdiomRemovesItsProgressAndExamples() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let idiom = try container.wordEditor.addIdiom(text: "spill the beans", meaning: "проболтаться", example: "Don't spill the beans.")
        try container.wordStatus.markKnown(wordID: idiom.id)

        try container.wordEditor.delete(idiom)

        #expect(try container.words.word(id: idiom.id) == nil)
        #expect(try container.words.examples(forWordID: idiom.id).isEmpty)
        #expect(try container.progress.progress(forWordID: idiom.id) == nil)
    }

    @Test func builtInIdiomCannotBeDeletedByHand() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let builtIn = Word(lemma: "under the weather", translation: "неважно себя чувствовать", partOfSpeech: Word.idiomPartOfSpeech, origin: .builtin, createdAt: clock.now)
        container.words.insert(builtIn)
        try container.persistence.save()

        #expect(throws: WordEditorError.builtIn) {
            try container.wordEditor.delete(builtIn)
        }
        #expect(try container.words.word(id: builtIn.id) != nil)
    }

    @Test func oldPhraseTableMovesIntoWordsOnce() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let legacy = PhraseEntity()
        legacy.id = UUID()
        legacy.text = "under the weather"
        legacy.meaning = "неважно себя чувствовать"
        legacy.example = "I feel under the weather today."
        legacy.userExamplesJSON = #"["He is under the weather."]"#
        legacy.note = "from a film"
        legacy.isKnown = true
        legacy.createdAt = clock.now
        container.persistence.context.insert(legacy)
        try container.persistence.save()
        let defaults = UserDefaults(suiteName: "idiom-migration-\(UUID())")!

        try PhraseMigration.run(persistence: container.persistence, words: container.words, wordStatus: container.wordStatus, defaults: defaults)
        try PhraseMigration.run(persistence: container.persistence, words: container.words, wordStatus: container.wordStatus, defaults: defaults)

        let idioms = try container.words.page(offset: 0, limit: 10, kind: .idioms)
        #expect(idioms.map(\.lemma) == ["under the weather"])
        #expect(idioms.first?.userNote == "from a film")
        #expect(try container.progress.progress(forWordID: idioms[0].id)?.status == .known)
        let examples = try container.words.examples(forWordID: idioms[0].id).map(\.sentence)
        #expect(examples.count == 2)
        #expect(try container.persistence.context.fetchCount(FetchDescriptor<PhraseEntity>()) == 0)
    }
}
