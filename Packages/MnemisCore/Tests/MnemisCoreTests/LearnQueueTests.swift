import Testing
import Foundation
@testable import MnemisCore

struct LearnQueueTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func progress(for word: Word, status: LearningStatus, nextReviewAt: Date?, createdAt: Date) -> LearningProgress {
        let progress = LearningProgress(wordID: word.id, createdAt: createdAt)
        progress.status = status
        progress.nextReviewAt = nextReviewAt
        return progress
    }

    @Test func dueReviewsComeBeforeNewWords() {
        let review = Word(lemma: "accomplish", origin: .builtin)
        let fresh = Word(lemma: "achieve", origin: .builtin)
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        let due = progress(for: review, status: .reviewing, nextReviewAt: now.addingTimeInterval(-60), createdAt: lastWeek)

        let queue = LearnQueue.make(words: [fresh, review], progress: [due], dailyNewLimit: 5, now: now, calendar: calendar)

        #expect(queue.map(\.lemma) == ["accomplish", "achieve"])
    }

    @Test func notYetDueWordsAreSkipped() {
        let word = Word(lemma: "accomplish", origin: .builtin)
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        let later = progress(for: word, status: .reviewing, nextReviewAt: now.addingTimeInterval(3600), createdAt: lastWeek)

        let queue = LearnQueue.make(words: [word], progress: [later], dailyNewLimit: 5, now: now, calendar: calendar)

        #expect(queue.isEmpty)
    }

    @Test func newWordsStartedTodayCountTowardLimit() {
        let started = Word(lemma: "accomplish", origin: .builtin)
        let candidates = ["achieve", "consistent", "diligent"].map { Word(lemma: $0, origin: .builtin) }
        let startedToday = progress(
            for: started,
            status: .learning,
            nextReviewAt: now.addingTimeInterval(600),
            createdAt: now
        )

        let queue = LearnQueue.make(
            words: [started] + candidates,
            progress: [startedToday],
            dailyNewLimit: 2,
            now: now,
            calendar: calendar
        )

        #expect(queue.map(\.lemma) == ["achieve"])
    }

    @Test func cachedAPIWordsAreNotOfferedAsNew() {
        let cached = Word(lemma: "serendipity", origin: .api)

        let queue = LearnQueue.make(words: [cached], progress: [], dailyNewLimit: 5, now: now, calendar: calendar)

        #expect(queue.isEmpty)
    }
}
