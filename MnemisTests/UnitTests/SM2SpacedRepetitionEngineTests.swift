import Testing
import Foundation
@testable import Mnemis

struct SM2SpacedRepetitionEngineTests {
    let engine = SM2SpacedRepetitionEngine()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func progress(
        status: LearningStatus = .reviewing,
        interval: Double = 10,
        difficulty: Double = 2.5,
        repetitions: Int = 3
    ) -> WordProgress {
        var progress = WordProgress(wordID: UUID(), createdAt: now)
        progress.status = status
        progress.intervalDays = interval
        progress.difficulty = difficulty
        progress.repetitionCount = repetitions
        return progress
    }

    @Test func firstGoodMovesNewWordToReviewingForOneDay() {
        let result = engine.schedule(progress(status: .new, interval: 0, repetitions: 0), rating: .good, now: now)

        #expect(result.status == .reviewing)
        #expect(result.intervalDays == 1)
        #expect(result.repetitionCount == 1)
        #expect(result.nextReviewAt == now.addingTimeInterval(86_400))
        #expect(result.introducedAt == now)
    }

    @Test func secondGoodUsesThreeDayStep() {
        let first = engine.schedule(progress(status: .new, interval: 0, repetitions: 0), rating: .good, now: now)
        let second = engine.schedule(first, rating: .good, now: now)

        #expect(second.intervalDays == 3)
        #expect(second.repetitionCount == 2)
    }

    @Test func easyOnFirstShowSchedulesFourDays() {
        let result = engine.schedule(progress(status: .new, interval: 0, repetitions: 0), rating: .easy, now: now)

        #expect(result.intervalDays == 4)
    }

    @Test func againSchedulesTenMinutesAndRestartsLadder() {
        let result = engine.schedule(progress(), rating: .again, now: now)

        #expect(result.status == .learning)
        #expect(abs(result.intervalDays - 10.0 / 1440.0) < 1e-9)
        #expect(result.repetitionCount == 0)
        #expect(result.incorrectCount == 1)
        #expect(result.nextReviewAt == now.addingTimeInterval(600))
    }

    @Test func goodAfterAgainReturnsToFirstStep() {
        let afterAgain = engine.schedule(progress(), rating: .again, now: now)
        let result = engine.schedule(afterAgain, rating: .good, now: now)

        #expect(result.intervalDays == 1)
        #expect(result.status == .reviewing)
    }

    @Test func goodAfterLadderUsesDifficultyMultiplier() {
        let result = engine.schedule(progress(difficulty: 2.0), rating: .good, now: now)

        #expect(result.intervalDays == 20)
    }

    @Test func difficultyStaysWithinBounds() {
        var hard = progress(difficulty: 1.4)
        for _ in 0..<5 {
            hard = engine.schedule(hard, rating: .again, now: now)
        }
        #expect(hard.difficulty == 1.3)

        var easy = progress(difficulty: 2.9)
        for _ in 0..<5 {
            easy = engine.schedule(easy, rating: .easy, now: now)
        }
        #expect(easy.difficulty == 3.0)
    }

    @Test func knownAndSuspendedWordsAreNotRescheduled() {
        let known = progress(status: .known)
        let suspended = progress(status: .suspended)

        #expect(engine.schedule(known, rating: .good, now: now) == known)
        #expect(engine.schedule(suspended, rating: .good, now: now) == suspended)
    }

    @Test func reviewingBecomesRememberedAfterThreshold() {
        // Интервал 10 * 2.5 = 25 дней, это больше порога 21 день.
        let result = engine.schedule(progress(), rating: .good, now: now)

        #expect(result.intervalDays == 25)
        #expect(result.status == .remembered)
    }

    @Test func rememberedFallsBackToReviewingOnAgain() {
        let result = engine.schedule(progress(status: .remembered, interval: 30), rating: .again, now: now)

        #expect(result.status == .reviewing)
    }

    @Test func countersTrackCorrectAndIncorrectAnswers() {
        var state = WordProgress(wordID: UUID(), createdAt: now)
        state = engine.schedule(state, rating: .hard, now: now)
        state = engine.schedule(state, rating: .again, now: now)
        state = engine.schedule(state, rating: .good, now: now)

        #expect(state.correctCount == 2)
        #expect(state.incorrectCount == 1)
    }
}
