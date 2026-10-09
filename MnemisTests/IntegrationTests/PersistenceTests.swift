import Testing
import Foundation
@testable import Mnemis

/// Хранение: связь прогресса со словом, история повторений, сохранность пользовательского контента.
@MainActor
struct PersistenceTests {
    let clock = TestClock()

    @Test func wordAndProgressRoundTrip() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = Word(lemma: "accomplish", translation: "выполнять", origin: .builtin, createdAt: clock.now)
        try container.words.upsert(word)
        try container.persistence.save()

        let stored = try #require(try container.words.word(id: word.id))
        #expect(stored.lemma == "accomplish")
        #expect(stored.translation == "выполнять")

        try container.submitReview.execute(wordID: word.id, rating: .good)
        let progress = try #require(try container.progress.progress(forWordID: word.id))
        #expect(progress.wordID == word.id)
        #expect(progress.status == .reviewing)
    }

    @Test func reviewHistoryIsAppendedNotOverwritten() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = Word(lemma: "achieve", origin: .builtin, createdAt: clock.now)
        try container.words.upsert(word)
        try container.persistence.save()

        try container.submitReview.execute(wordID: word.id, rating: .good)
        try container.submitReview.execute(wordID: word.id, rating: .again)

        let history = try container.reviews.all()
        #expect(history.count == 2)
        #expect(Set(history.map(\.rating)) == [.good, .again])
        #expect(try container.progress.all().count == 1)
    }

    @Test func knownWordCannotBeReviewed() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = Word(lemma: "achieve", origin: .builtin, createdAt: clock.now)
        try container.words.upsert(word)
        try container.persistence.save()
        try container.wordStatus.markKnown(wordID: word.id)

        #expect(throws: ReviewError.wordNotSchedulable) {
            try container.submitReview.execute(wordID: word.id, rating: .good)
        }
        #expect(try container.reviews.all().isEmpty)
    }

    @Test func settingsDefaultThenPersist() throws {
        let container = try AppContainer.inMemory(clock: clock)
        #expect(try container.settings.load().onboardingCompleted == false)

        try container.settings.update { $0.onboardingCompleted = true; $0.newWordsPerDay = 12 }

        let loaded = try container.settings.load()
        #expect(loaded.onboardingCompleted)
        #expect(loaded.newWordsPerDay == 12)
    }

    @Test func newWordsPerDayIsClampedToAllowedRange() throws {
        let container = try AppContainer.inMemory(clock: clock)
        try container.settings.update { $0.newWordsPerDay = 500 }
        #expect(try container.settings.load().newWordsPerDay == UserSettings.newWordsRange.upperBound)
    }
}
