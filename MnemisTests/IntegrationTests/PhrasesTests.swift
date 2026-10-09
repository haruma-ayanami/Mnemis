import Foundation
import Testing
@testable import Mnemis

/// Личные идиомы: добавление, поиск, идиома дня и поиск с точным совпадением первым (ABOUT.md, разделы 5, 9.1, 14).
@MainActor
struct PhrasesTests {
    let clock = TestClock()

    @Test func addsIdiomWithMeaningAndExample() throws {
        let container = try AppContainer.inMemory(clock: clock)

        try container.phraseEditor.add(text: "  break the ice ", meaning: "разрядить обстановку", example: " A joke helped. ")

        let stored = try #require(try container.phrases.all().first)
        #expect(stored.text == "break the ice")
        #expect(stored.example == "A joke helped.")
    }

    @Test func rejectsEmptyTextAndEmptyMeaning() throws {
        let container = try AppContainer.inMemory(clock: clock)

        #expect(throws: PhraseEditorError.emptyText) {
            try container.phraseEditor.add(text: "   ", meaning: "перевод")
        }
        #expect(throws: PhraseEditorError.emptyMeaning) {
            try container.phraseEditor.add(text: "spill the beans", meaning: " ")
        }
        #expect(try container.phrases.count() == 0)
    }

    @Test func searchFindsByMeaning() throws {
        let container = try AppContainer.inMemory(clock: clock)
        try container.phraseEditor.add(text: "break the ice", meaning: "разрядить обстановку")
        try container.phraseEditor.add(text: "hit the books", meaning: "засесть за учебники")

        #expect(try container.phrases.search("обстановку").map(\.text) == ["break the ice"])
        #expect(try container.phrases.count() == 2)
    }

    @Test func rejectsTheSameIdiomTwice() throws {
        let container = try AppContainer.inMemory(clock: clock)
        try container.phraseEditor.add(text: "break the ice", meaning: "разрядить обстановку")

        #expect(throws: PhraseEditorError.duplicate) {
            try container.phraseEditor.add(text: "  Break the ICE ", meaning: "сделать первый шаг")
        }
        #expect(try container.phrases.count() == 1)
    }

    @Test func phraseOfDayIsStableWithinADayAndNilWithoutPhrases() throws {
        let container = try AppContainer.inMemory(clock: clock)
        #expect(try container.phrases.phraseOfDay(dayID: "2026-10-09") == nil)

        try container.phraseEditor.add(text: "break the ice", meaning: "разрядить обстановку")
        try container.phraseEditor.add(text: "hit the books", meaning: "много учиться")
        try container.phraseEditor.add(text: "under the weather", meaning: "неважно себя чувствовать")

        let first = try container.phrases.phraseOfDay(dayID: "2026-10-09")
        let again = try container.phrases.phraseOfDay(dayID: "2026-10-09")
        #expect(first != nil)
        #expect(first == again)
    }

    @Test func phrasesInTodayIsStoredInSettings() throws {
        let container = try AppContainer.inMemory(clock: clock)
        #expect(try container.settings.load().phrasesInToday)

        try container.settings.update { $0.phrasesInToday = false }

        #expect(try container.settings.load().phrasesInToday == false)
    }

    @Test func idiomKeepsUserExamplesNoteAndKnownFlag() throws {
        let container = try AppContainer.inMemory(clock: clock)
        var idiom = try container.phraseEditor.add(text: "break the ice", meaning: "сделать первый шаг", example: "A joke can break the ice.")

        idiom = try container.phraseEditor.addExample("  We played a game to break the ice. ", to: idiom)
        idiom = try container.phraseEditor.addExample("A joke can break the ice.", to: idiom)
        idiom = try container.phraseEditor.setNote(" heard it at work ", for: idiom)
        idiom = try container.phraseEditor.setKnown(true, for: idiom)

        let stored = try #require(try container.phrases.phrase(id: idiom.id))
        #expect(stored.userExamples == ["We played a game to break the ice."])
        #expect(stored.note == "heard it at work")
        #expect(stored.isKnown)
        #expect(try container.phrases.search("game").map(\.id) == [idiom.id])
    }

    @Test func idiomOfTheDayPrefersIdiomsStillBeingLearned() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let known = try container.phraseEditor.add(text: "break the ice", meaning: "сделать первый шаг")
        _ = try container.phraseEditor.setKnown(true, for: known)
        let learning = try container.phraseEditor.add(text: "hit the books", meaning: "засесть за учебники")

        for day in ["2026-10-09", "2026-10-10", "2026-10-11"] {
            #expect(try container.phrases.phraseOfDay(dayID: day)?.id == learning.id)
        }
    }

    @Test func deletingPhraseRemovesIt() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let phrase = try container.phraseEditor.add(text: "once in a blue moon", meaning: "неважно себя чувствовать")

        try container.phraseEditor.delete(id: phrase.id)

        #expect(try container.phrases.count() == 0)
    }

    @Test func exactMatchComesBeforePrefixAndContainsMatches() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        for lemma in ["achievement", "unachieved", "achieve"] {
            container.words.insert(Word(lemma: lemma, origin: .builtin, createdAt: created))
        }
        try container.persistence.save()

        let result = try container.words.search("achieve", limit: 10).map(\.lemma)

        #expect(result == ["achieve", "achievement", "unachieved"])
    }
}
