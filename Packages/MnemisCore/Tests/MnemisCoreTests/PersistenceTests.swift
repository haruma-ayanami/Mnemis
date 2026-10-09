import Testing
import Foundation
import SwiftData
@testable import MnemisCore

@MainActor
struct PersistenceTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    /// Контейнер держим в наборе: `mainContext` недействителен после освобождения контейнера.
    private let container: ModelContainer

    init() throws {
        container = try MnemisStore.makeContainer(inMemory: true)
    }

    private func makeContext() -> ModelContext {
        container.mainContext
    }

    @Test func ratingCreatesOneProgressRecordAndHistoryEntries() throws {
        let context = makeContext()
        let word = Word(lemma: "accomplish")
        context.insert(word)
        let service = ReviewService(engine: SM2SpacedRepetitionEngine(), context: context)

        let first = try service.rate(wordID: word.id, rating: .good, now: now)
        #expect(first.status == .reviewing)

        try service.rate(wordID: word.id, rating: .good, now: now)

        let progress = try context.fetch(FetchDescriptor<LearningProgress>())
        let reviews = try context.fetch(FetchDescriptor<Review>())
        #expect(progress.count == 1)
        #expect(progress.first?.repetitionCount == 2)
        #expect(reviews.count == 2)
    }

    @Test func markKnownStopsScheduling() throws {
        let context = makeContext()
        let word = Word(lemma: "achieve")
        context.insert(word)
        let service = ReviewService(engine: SM2SpacedRepetitionEngine(), context: context)

        try service.rate(wordID: word.id, rating: .good, now: now)
        try service.markKnown(wordID: word.id, now: now)

        let progress = try #require(try context.fetch(FetchDescriptor<LearningProgress>()).first)
        #expect(progress.status == .known)
        #expect(progress.nextReviewAt == nil)
        #expect(progress.isDue(at: .distantFuture) == false)
    }

    @Test func dailyWordIsStableWithinADay() throws {
        let context = makeContext()
        context.insert(Word(lemma: "accomplish", origin: .builtin))
        context.insert(Word(lemma: "achieve", origin: .builtin))
        let service = DailyWordService(context: context)

        let morning = try service.word(for: now)
        let evening = try service.word(for: now.addingTimeInterval(3600))

        #expect(morning != nil)
        #expect(morning?.id == evening?.id)
        #expect(try context.fetch(FetchDescriptor<DailyWord>()).count == 1)
    }
}
