import Testing
import Foundation
@testable import Mnemis

struct LearningSessionTests {
    let clock = TestClock()

    private var now: Date { clock.now }

    private func progress(_ word: Word, status: LearningStatus, nextReviewAt: Date?, introducedAt: Date?) -> WordProgress {
        var progress = WordProgress(wordID: word.id, createdAt: now.addingTimeInterval(-7 * 86_400))
        progress.status = status
        progress.nextReviewAt = nextReviewAt
        progress.introducedAt = introducedAt
        return progress
    }

    @Test func dueReviewsComeBeforeNewWords() {
        let review = Word(lemma: "accomplish", origin: .builtin, createdAt: now)
        let fresh = Word(lemma: "achieve", origin: .builtin, createdAt: now)
        let due = progress(review, status: .reviewing, nextReviewAt: now.addingTimeInterval(-60), introducedAt: now.addingTimeInterval(-86_400))

        let queue = LearningSession.queue(
            words: [fresh, review],
            progress: [due],
            dailyWordID: nil,
            newWordsPerDay: 5,
            startedToday: 0,
            now: now
        )

        #expect(queue.map(\.lemma) == ["accomplish", "achieve"])
    }

    @Test func dailyWordComesFirstAmongNewWords() {
        let common = Word(lemma: "achieve", frequencyRank: 100, origin: .builtin, createdAt: now)
        let daily = Word(lemma: "thorough", frequencyRank: 5000, origin: .builtin, createdAt: now)

        let queue = LearningSession.queue(
            words: [common, daily],
            progress: [],
            dailyWordID: daily.id,
            newWordsPerDay: 1,
            startedToday: 0,
            now: now
        )

        #expect(queue.map(\.lemma) == ["thorough"])
    }

    @Test func newWordsStartedTodayCountTowardLimit() {
        let started = Word(lemma: "accomplish", origin: .builtin, createdAt: now)
        let candidates = ["achieve", "consistent", "diligent"].map { Word(lemma: $0, origin: .builtin, createdAt: now) }
        let startedProgress = progress(started, status: .learning, nextReviewAt: now.addingTimeInterval(600), introducedAt: now)

        let queue = LearningSession.queue(
            words: [started] + candidates,
            progress: [startedProgress],
            dailyWordID: nil,
            newWordsPerDay: 2,
            startedToday: LearningSession.startedToday(progress: [startedProgress], now: now, calendar: clock.calendar),
            now: now
        )

        #expect(queue.map(\.lemma) == ["achieve"])
    }

    @Test func dueReviewsIgnoreNewWordLimit() {
        let review = Word(lemma: "accomplish", origin: .builtin, createdAt: now)
        let due = progress(review, status: .reviewing, nextReviewAt: now.addingTimeInterval(-60), introducedAt: now.addingTimeInterval(-86_400))

        let queue = LearningSession.queue(
            words: [review],
            progress: [due],
            dailyWordID: nil,
            newWordsPerDay: 0,
            startedToday: 0,
            now: now
        )

        #expect(queue.map(\.lemma) == ["accomplish"])
    }

    @Test func cachedAPIWordsAreNotOfferedAsNew() {
        let cached = Word(lemma: "serendipity", origin: .api, createdAt: now)

        let queue = LearningSession.queue(
            words: [cached],
            progress: [],
            dailyWordID: nil,
            newWordsPerDay: 5,
            startedToday: 0,
            now: now
        )

        #expect(queue.isEmpty)
    }

    @Test func startedTodayOnlyCountsTodaysIntroductions() {
        let yesterday = progress(Word(lemma: "a", createdAt: now), status: .reviewing, nextReviewAt: nil, introducedAt: now.addingTimeInterval(-86_400 * 2))
        let today = progress(Word(lemma: "b", createdAt: now), status: .learning, nextReviewAt: nil, introducedAt: now)

        let count = LearningSession.startedToday(progress: [yesterday, today], now: now, calendar: clock.calendar)

        #expect(count == 1)
    }
}
