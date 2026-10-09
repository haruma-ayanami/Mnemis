import Testing
import Foundation
@testable import Mnemis

/// Критические сценарии из ARCHITECTURE.md, раздел 13.
@MainActor
struct UserJourneyTests {
    let clock = TestClock()

    private func offlineDictionary() -> DictionaryService {
        DictionaryService(providers: [StubDictionaryProvider(sourceID: "api", entry: nil, error: APIError.transport)])
    }

    @Test func reviewSurvivesRelaunch() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mnemis-test-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let wordID: UUID
        do {
            let persistence = try PersistenceController.make(storeURL: storeURL)
            let container = AppContainer(persistence: persistence, clock: clock)
            let word = Word(lemma: "accomplish", origin: .builtin, createdAt: clock.now)
            try container.words.upsert(word)
            try persistence.save()
            try container.submitReview.execute(wordID: word.id, rating: .good)
            wordID = word.id
        }

        // Новый контейнер на том же файле — имитация перезапуска приложения.
        let relaunched = AppContainer(persistence: try PersistenceController.make(storeURL: storeURL), clock: clock)
        let progress = try #require(try relaunched.progress.progress(forWordID: wordID))
        #expect(progress.status == .reviewing)
        #expect(try relaunched.reviews.all().count == 1)
    }

    @Test func wordIsSavedWithoutNetwork() throws {
        let container = try AppContainer.inMemory(clock: clock, dictionary: offlineDictionary())

        let word = try container.wordEditor.addWord(lemma: "serendipity", translation: "счастливая случайность")

        #expect(try container.words.word(id: word.id)?.translation == "счастливая случайность")
    }

    @Test func enrichmentReportsUnavailableWithoutLosingWord() async throws {
        let container = try AppContainer.inMemory(clock: clock, dictionary: offlineDictionary())
        let word = try container.wordEditor.addWord(lemma: "serendipity", translation: "")

        let outcome = try await container.wordEnrichment.enrich(wordID: word.id)

        #expect(outcome == .unavailable)
        #expect(try container.words.word(id: word.id) != nil)
    }

    @Test func enrichmentFillsGapsButKeepsUserContent() async throws {
        let entry = Fixtures.entry(lemma: "achieve", ipa: "/əˈtʃiːv/", definition: "to reach a goal", examples: ["He achieved it."])
        let container = try AppContainer.inMemory(
            clock: clock,
            dictionary: DictionaryService(providers: [StubDictionaryProvider(sourceID: "api", entry: entry, error: nil)])
        )

        var word = Word(lemma: "achieve", translation: "мой перевод", origin: .builtin, createdAt: clock.now)
        word.definition = "my own definition"
        try container.words.upsert(word)
        try container.persistence.save()
        try container.wordEditor.addExample(wordID: word.id, sentence: "I will achieve my IELTS goal.")

        let outcome = try await container.wordEnrichment.enrich(wordID: word.id)

        let updated = try #require(try container.words.word(id: word.id))
        #expect(outcome == .updated(fieldsAdded: 3))
        #expect(updated.ipa == "/əˈtʃiːv/")
        #expect(updated.translation == "мой перевод")
        #expect(updated.definition == "my own definition")

        let examples = try container.words.examples(forWordID: word.id)
        #expect(examples.contains { $0.isUserCreated && $0.sentence == "I will achieve my IELTS goal." })
        #expect(examples.contains { !$0.isUserCreated && $0.sentence == "He achieved it." })
    }

    @Test func enrichingTwiceAddsNothingNew() async throws {
        let entry = Fixtures.entry(lemma: "achieve", examples: ["He achieved it."])
        let container = try AppContainer.inMemory(
            clock: clock,
            dictionary: DictionaryService(providers: [StubDictionaryProvider(sourceID: "api", entry: entry, error: nil)])
        )
        let word = try container.wordEditor.addWord(lemma: "achieve", translation: "")

        _ = try await container.wordEnrichment.enrich(wordID: word.id)
        let second = try await container.wordEnrichment.enrich(wordID: word.id)

        #expect(second == .nothingToAdd)
    }

    @Test func dailyWordIsStableAcrossRelaunchesWithinADay() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mnemis-daily-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: storeURL) }

        let first: Word?
        do {
            let container = AppContainer(persistence: try PersistenceController.make(storeURL: storeURL), clock: clock)
            try container.words.upsert(Word(lemma: "accomplish", frequencyRank: 1, origin: .builtin, createdAt: clock.now))
            try container.words.upsert(Word(lemma: "achieve", frequencyRank: 2, origin: .builtin, createdAt: clock.now))
            try container.persistence.save()
            first = try container.dailyWordUseCase.todaysWord(preferredLevel: nil)
        }

        let later = AppContainer(persistence: try PersistenceController.make(storeURL: storeURL), clock: clock.advanced(by: 3600))
        let second = try later.dailyWordUseCase.todaysWord(preferredLevel: nil)

        #expect(first != nil)
        #expect(first?.id == second?.id)
    }

    @Test func emptyDictionaryShowsNoDailyWord() throws {
        let container = try AppContainer.inMemory(clock: clock)
        #expect(try container.dailyWordUseCase.todaysWord(preferredLevel: nil) == nil)
    }
}
