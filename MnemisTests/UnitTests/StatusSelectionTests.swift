import Foundation
import Testing
@testable import Mnemis

/// Ручной выбор статуса идиомы: интервалы совпадают с движком повторений, известное не планируется, выбор сохраняется.
@MainActor
struct StatusSelectionTests {
    let clock = TestClock()
    private let day: TimeInterval = 86_400

    private func progress(_ status: LearningStatus) -> WordProgress {
        var progress = WordProgress(wordID: UUID(), createdAt: clock.now)
        progress.status = status
        progress.nextReviewAt = clock.now.addingTimeInterval(day)
        return progress
    }

    @Test func learningComesBackTomorrow() {
        let result = LearningRules.setStatus(progress(.known), to: .learning, now: clock.now)
        #expect(result.status == .learning)
        #expect(result.intervalDays == SM2SpacedRepetitionEngine.learningSteps[0])
        #expect(result.nextReviewAt == clock.now.addingTimeInterval(day))
    }

    @Test func reviewingUsesTheLastLearningStep() {
        let result = LearningRules.setStatus(progress(.learning), to: .reviewing, now: clock.now)
        #expect(result.status == .reviewing)
        #expect(result.intervalDays == SM2SpacedRepetitionEngine.learningSteps.last!)
        #expect(result.nextReviewAt == clock.now.addingTimeInterval(result.intervalDays * day))
    }

    @Test func rememberedUsesTheThreshold() {
        let result = LearningRules.setStatus(progress(.reviewing), to: .remembered, now: clock.now)
        #expect(result.status == .remembered)
        #expect(result.intervalDays == SM2SpacedRepetitionEngine.rememberedThresholdDays)
        #expect(result.nextReviewAt == clock.now.addingTimeInterval(SM2SpacedRepetitionEngine.rememberedThresholdDays * day))
    }

    @Test func knownIsNotScheduledAndCanBeSetBack() {
        let known = LearningRules.setStatus(progress(.reviewing), to: .known, now: clock.now)
        #expect(known.status == .known)
        #expect(known.nextReviewAt == nil)

        let back = LearningRules.setStatus(known, to: .reviewing, now: clock.now)
        #expect(back.status == .reviewing)
        #expect(back.nextReviewAt != nil)
    }

    @Test func rememberedStaysRememberedAfterAGoodRating() {
        let remembered = LearningRules.setStatus(progress(.reviewing), to: .remembered, now: clock.now)
        let next = SM2SpacedRepetitionEngine().schedule(remembered, rating: .good, now: clock.now)
        #expect(next.status == .remembered)
    }

    @Test func choiceIsStoredForTheWord() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let idiom = Word(lemma: "break the ice", partOfSpeech: Word.idiomPartOfSpeech, origin: .builtin, createdAt: clock.now)
        container.words.insert(idiom)
        try container.persistence.save()

        try container.wordStatus.setStatus(wordID: idiom.id, to: .remembered)

        let stored = try #require(try container.progress.progress(forWordID: idiom.id))
        #expect(stored.status == .remembered)
        #expect(stored.nextReviewAt == clock.now.addingTimeInterval(SM2SpacedRepetitionEngine.rememberedThresholdDays * day))
    }
}
