import Testing
import Foundation
@testable import MnemisCore

struct SM2SpacedRepetitionEngineTests {
    let engine = SM2SpacedRepetitionEngine()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func reviewingState(interval: Double, difficulty: Double = 2.5, repetitions: Int = 3) -> SchedulingState {
        SchedulingState(
            status: .reviewing,
            repetitionCount: repetitions,
            correctCount: 0,
            incorrectCount: 0,
            difficulty: difficulty,
            stability: interval,
            interval: interval,
            lastReviewedAt: nil,
            nextReviewAt: nil
        )
    }

    @Test func firstGoodMovesNewWordToReviewingForOneDay() {
        let result = engine.schedule(.initial, rating: .good, now: now)

        #expect(result.status == .reviewing)
        #expect(result.interval == 1)
        #expect(result.repetitionCount == 1)
        #expect(result.nextReviewAt == now.addingTimeInterval(86_400))
    }

    @Test func secondGoodUsesThreeDayStep() {
        let first = engine.schedule(.initial, rating: .good, now: now)
        let second = engine.schedule(first, rating: .good, now: now)

        #expect(second.interval == 3)
        #expect(second.repetitionCount == 2)
    }

    @Test func easyOnFirstShowSchedulesFourDays() {
        let result = engine.schedule(.initial, rating: .easy, now: now)

        #expect(result.interval == 4)
        #expect(result.status == .reviewing)
    }

    @Test func againSchedulesTenMinutesAndRestartsLadder() {
        let result = engine.schedule(reviewingState(interval: 10), rating: .again, now: now)

        #expect(result.status == .learning)
        #expect(abs(result.interval - 10.0 / 1440.0) < 1e-9)
        #expect(result.repetitionCount == 0)
        #expect(result.incorrectCount == 1)
        #expect(result.nextReviewAt == now.addingTimeInterval(600))
    }

    @Test func goodAfterAgainReturnsToFirstStep() {
        let afterAgain = engine.schedule(reviewingState(interval: 10), rating: .again, now: now)
        let result = engine.schedule(afterAgain, rating: .good, now: now)

        #expect(result.interval == 1)
        #expect(result.status == .reviewing)
    }

    @Test func goodAfterLadderUsesDifficultyMultiplier() {
        let result = engine.schedule(reviewingState(interval: 10, difficulty: 2.0), rating: .good, now: now)

        #expect(result.interval == 20)
    }

    @Test func difficultyStaysWithinBounds() {
        var state = reviewingState(interval: 10, difficulty: 1.4)
        for _ in 0..<5 {
            state = engine.schedule(state, rating: .again, now: now)
        }
        #expect(state.difficulty == 1.3)

        var easyState = reviewingState(interval: 10, difficulty: 2.9)
        for _ in 0..<5 {
            easyState = engine.schedule(easyState, rating: .easy, now: now)
        }
        #expect(easyState.difficulty == 3.0)
    }

    @Test func knownAndSuspendedWordsAreNotRescheduled() {
        var known = reviewingState(interval: 10)
        known.status = .known
        var suspended = reviewingState(interval: 10)
        suspended.status = .suspended

        #expect(engine.schedule(known, rating: .good, now: now) == known)
        #expect(engine.schedule(suspended, rating: .good, now: now) == suspended)
    }

    @Test func reviewingBecomesRememberedAfterThreshold() {
        // Интервал 10 * 2.5 = 25 дней, это больше порога 21 день.
        let result = engine.schedule(reviewingState(interval: 10), rating: .good, now: now)

        #expect(result.interval == 25)
        #expect(result.status == .remembered)
    }

    @Test func rememberedFallsBackToReviewingOnAgain() {
        var remembered = reviewingState(interval: 30)
        remembered.status = .remembered

        let result = engine.schedule(remembered, rating: .again, now: now)

        #expect(result.status == .reviewing)
    }

    @Test func countersTrackCorrectAndIncorrectAnswers() {
        var state = SchedulingState.initial
        state = engine.schedule(state, rating: .hard, now: now)
        state = engine.schedule(state, rating: .again, now: now)
        state = engine.schedule(state, rating: .good, now: now)

        #expect(state.correctCount == 2)
        #expect(state.incorrectCount == 1)
    }
}
