import Foundation
import Testing
@testable import Mnemis

/// Запросы к базе по прогрессу должны совпадать с чистой логикой (`ReviewScheduler`, `LearningRules`).
/// Так денормализованные поля не могут разойтись с правилами расписания.
@MainActor
struct ProgressQueryTests {
    let clock = TestClock()

    /// Прогресс с разными статусами, датами повторения и введения: все ветки запросов покрыты.
    private func seed(_ container: AppContainer) throws -> [WordProgress] {
        let now = clock.now
        let statuses: [LearningStatus] = [.learning, .reviewing, .remembered, .known, .suspended, .learning, .reviewing, .new]
        var rows: [WordProgress] = []
        for (index, status) in statuses.enumerated() {
            var progress = WordProgress(wordID: UUID(), createdAt: now)
            progress.status = status
            progress.nextReviewAt = index % 3 == 0 ? nil : now.addingTimeInterval(Double(index - 3) * 86_400)
            progress.introducedAt = index % 2 == 0 ? now.addingTimeInterval(-Double(index) * 3_600) : nil
            rows.append(progress)
            try container.progress.upsert(progress)
        }
        try container.persistence.save()
        return rows
    }

    @Test func dueMatchesSchedulerRules() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let rows = try seed(container)

        let fromDatabase = Set(try container.progress.due(at: clock.now).map(\.id))
        let expected = Set(ReviewScheduler.dueProgress(rows, at: clock.now).map(\.id))

        #expect(fromDatabase == expected)
        #expect(try container.progress.countDue(at: clock.now) == expected.count)
    }

    @Test func nextReviewDateMatchesScheduler() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let rows = try seed(container)

        #expect(try container.progress.nextReviewDate(after: clock.now) == ReviewScheduler.nextReviewDate(in: rows, after: clock.now))
    }

    @Test func masteredAndStatusCountsMatchRows() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let rows = try seed(container)

        #expect(try container.progress.countMastered() == rows.filter { $0.status == .remembered || $0.status == .known }.count)
        for status in LearningStatus.allCases {
            #expect(try container.progress.count(status: status) == rows.filter { $0.status == status }.count)
        }
    }

    @Test func introducedCountsMatchRows() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let rows = try seed(container)
        let since = clock.now.addingTimeInterval(-5 * 3_600)

        #expect(try container.progress.countIntroduced(since: nil) == rows.filter { $0.introducedAt != nil }.count)
        #expect(try container.progress.countIntroduced(since: since) == rows.filter { ($0.introducedAt ?? .distantPast) >= since }.count)
    }

    @Test func scheduledWindowMatchesRows() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let rows = try seed(container)
        let end = clock.now.addingTimeInterval(86_400)

        let expected = rows.filter { LearningRules.isSchedulable($0.status) && ($0.nextReviewAt ?? .distantFuture) > clock.now && ($0.nextReviewAt ?? .distantFuture) < end }
        #expect(try container.progress.countScheduled(after: clock.now, before: end) == expected.count)
    }

    @Test func notStartedWordsMatchProgressRows() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let word = Word(lemma: "accomplish", origin: .builtin, createdAt: clock.now)
        container.words.insert(word)
        try container.persistence.save()
        #expect(try container.words.countNotStarted() == 1)

        try container.progress.upsert(WordProgress(wordID: word.id, createdAt: clock.now))
        try container.persistence.save()

        #expect(try container.words.countNotStarted() == 0)
    }
}
