import Testing
import Foundation
@testable import Mnemis

struct LearningRulesTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func progress(_ status: LearningStatus) -> WordProgress {
        var progress = WordProgress(wordID: UUID(), createdAt: now)
        progress.status = status
        progress.nextReviewAt = now.addingTimeInterval(86_400)
        return progress
    }

    @Test func knownAndSuspendedAreNotSchedulable() {
        #expect(!LearningRules.isSchedulable(.known))
        #expect(!LearningRules.isSchedulable(.suspended))
        #expect(LearningRules.isSchedulable(.reviewing))
    }

    @Test func markKnownStopsRepetitionsAndCanBeUndone() {
        let known = LearningRules.markKnown(progress(.reviewing), now: now)
        #expect(known.status == .known)
        #expect(known.nextReviewAt == nil)

        let restored = LearningRules.restoreToLearning(known, now: now)
        #expect(restored.status == .reviewing)
        #expect(restored.nextReviewAt == now)
    }

    @Test func suspendRemembersPreviousStatusAndResumeRestoresIt() {
        let suspended = LearningRules.suspend(progress(.remembered), now: now)
        #expect(suspended.status == .suspended)
        #expect(suspended.suspendedFromStatus == .remembered)
        #expect(suspended.nextReviewAt == nil)

        let resumed = LearningRules.resume(suspended, now: now)
        #expect(resumed.status == .remembered)
        #expect(resumed.suspendedFromStatus == nil)
        #expect(resumed.nextReviewAt == now)
    }

    @Test func suspendedWordCannotBeMarkedKnownDirectly() {
        let suspended = LearningRules.suspend(progress(.reviewing), now: now)
        #expect(LearningRules.markKnown(suspended, now: now) == suspended)
    }

    @Test func knownWordIsNotSuspendedAndResumesAsKnown() {
        let known = LearningRules.markKnown(progress(.reviewing), now: now)
        let suspended = LearningRules.suspend(known, now: now)
        let resumed = LearningRules.resume(suspended, now: now)

        #expect(resumed.status == .known)
        #expect(resumed.nextReviewAt == nil)
    }
}
