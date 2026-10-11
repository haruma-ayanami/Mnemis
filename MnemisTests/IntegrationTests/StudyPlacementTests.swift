import Foundation
import Testing
@testable import Mnemis

/// Ручное размещение слова из карточки: в колоду на сегодня, в Practice или на завтра.
@MainActor
struct StudyPlacementTests {
    let clock = TestClock()
    private let day: TimeInterval = 86_400

    private func makeWord(_ container: AppContainer, lemma: String = "diligent", rank: Int = 100) throws -> Word {
        let word = Word(lemma: lemma, translation: "усердный", partOfSpeech: "adjective", level: "B2",
                        frequencyRank: rank, origin: .builtin, createdAt: clock.now)
        container.words.insert(word)
        try container.persistence.save()
        return word
    }

    @Test func todayIsDueNowAndCountsAsNewToday() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try makeWord(container)

        try container.wordStatus.place(wordID: word.id, as: .today)

        let stored = try #require(try container.progress.progress(forWordID: word.id))
        #expect(stored.status == .learning)
        #expect(stored.nextReviewAt == clock.now)
        #expect(try container.progress.countDue(at: clock.now) == 1)
        #expect(try container.progress.countIntroduced(since: LocalDay.start(of: clock.now, calendar: clock.calendar)) == 1)
        #expect(LearningRules.placement(of: stored, now: clock.now) == .today)
    }

    @Test func practiceHasNoScheduleButIsInPractice() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try makeWord(container)

        try container.wordStatus.place(wordID: word.id, as: .practice)

        let stored = try #require(try container.progress.progress(forWordID: word.id))
        #expect(stored.nextReviewAt == nil)
        #expect(try container.progress.countDue(at: clock.now.addingTimeInterval(30 * day)) == 0)
        #expect(try container.progress.wordIDs(status: .learning).contains(word.id))
        #expect(LearningRules.placement(of: stored, now: clock.now) == .practice)
    }

    @Test func laterComesBackTomorrowWithoutUsingTodaysLimit() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try makeWord(container)

        try container.wordStatus.place(wordID: word.id, as: .later)

        let stored = try #require(try container.progress.progress(forWordID: word.id))
        #expect(stored.nextReviewAt == clock.now.addingTimeInterval(day))
        #expect(try container.progress.countDue(at: clock.now) == 0)
        #expect(try container.progress.countIntroduced(since: LocalDay.start(of: clock.now, calendar: clock.calendar)) == 0)
        #expect(LearningRules.placement(of: stored, now: clock.now) == .later)
    }

    @Test func removingReturnsTheWordToNew() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try makeWord(container)
        try container.wordStatus.place(wordID: word.id, as: .today)

        try container.wordStatus.removeFromStudy(wordID: word.id)

        #expect(try container.progress.progress(forWordID: word.id) == nil)
        #expect(try container.words.countFreshCandidates() == 1)
    }

    @Test func reviewedWordCanNoLongerBePlacedOrRemoved() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = try makeWord(container)
        try container.wordStatus.place(wordID: word.id, as: .today)
        try container.submitReview.execute(wordID: word.id, rating: .good)

        let stored = try #require(try container.progress.progress(forWordID: word.id))
        #expect(!LearningRules.canPlace(stored))
        try container.wordStatus.removeFromStudy(wordID: word.id)
        #expect(try container.progress.progress(forWordID: word.id) != nil)
    }

    @Test func runningSessionPicksUpAWordAddedToToday() throws {
        let container = try AppContainer.inMemory(clock: clock)
        // Больше пяти слов: дневной лимит новых слов не пускает «extra» в очередь сам.
        for index in 0..<6 { _ = try makeWord(container, lemma: "word\(index)", rank: index + 1) }
        let extra = try makeWord(container, lemma: "extra", rank: 99)
        let session = LearnViewModel(container: container)
        session.startIfNeeded()
        session.rate(.good)
        let before = session.queue.count

        try container.wordStatus.place(wordID: extra.id, as: .today)
        session.startIfNeeded()

        #expect(session.reviewedCount == 1)
        #expect(session.queue.count == before + 1)
        #expect(session.queue.contains { $0.id == extra.id })
    }
}

@MainActor
struct IdiomStudyPlacementTests {
    let clock = TestClock()

    @Test func notStartedIdiomCanBePlacedLikeAWord() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let idiom = Word(lemma: "break the ice", translation: "разрядить обстановку", partOfSpeech: Word.idiomPartOfSpeech,
                         origin: .builtin, createdAt: clock.now)
        container.words.insert(idiom)
        try container.persistence.save()
        let details = WordDetailsViewModel(word: idiom, container: container, onChange: {})
        #expect(details.canPlace)

        details.togglePlacement(.today)
        #expect(details.placement == .today)
        #expect(try container.progress.countDue(at: clock.now) == 1)

        details.togglePlacement(.today)
        #expect(details.placement == nil)
        #expect(try container.progress.progress(forWordID: idiom.id) == nil)
    }
}
