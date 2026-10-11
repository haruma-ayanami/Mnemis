import Foundation
import Testing
@testable import Mnemis

/// Переход через полночь: Learn собирает новую сессию, а не продолжает вчерашнюю.
@MainActor
struct DayRolloverTests {
    private func date(day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func addWords(_ count: Int, to container: AppContainer, clock: MovableClock) throws {
        for index in 0..<count {
            container.words.insert(Word(
                lemma: "word\(index)", translation: "слово", partOfSpeech: "noun", meanings: [],
                level: "A2", frequencyRank: index + 1, origin: .builtin, createdAt: clock.now
            ))
        }
        try container.persistence.save()
    }

    @Test func finishedSessionIsRebuiltOnTheNextDay() throws {
        let clock = MovableClock(now: date(day: 9, hour: 16))
        let container = try AppContainer.inMemory(clock: clock)
        try addWords(8, to: container, clock: clock)

        let session = LearnViewModel(container: container)
        session.startIfNeeded()
        #expect(session.queue.count == 5)
        for _ in 0..<5 { session.rate(.good) }
        #expect(session.isSessionFinished)

        clock.now = date(day: 10, hour: 12)
        session.startIfNeeded()

        #expect(session.reviewedCount == 0)
        #expect(!session.queue.isEmpty)
    }

    @Test func unfinishedSessionOfTheSameDayKeepsItsResults() throws {
        let clock = MovableClock(now: date(day: 9, hour: 16))
        let container = try AppContainer.inMemory(clock: clock)
        try addWords(8, to: container, clock: clock)

        let session = LearnViewModel(container: container)
        session.startIfNeeded()
        session.rate(.good)
        session.rate(.good)

        clock.now = date(day: 9, hour: 20)
        session.startIfNeeded()

        #expect(session.reviewedCount == 2)
    }
}
