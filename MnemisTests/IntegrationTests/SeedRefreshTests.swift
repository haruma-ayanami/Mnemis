import Foundation
import Testing
@testable import Mnemis

/// Обновление встроенного словаря до новой версии и значения по частям речи (ABOUT.md, раздел 13).
@MainActor
struct SeedRefreshTests {
    let clock = TestClock()
    private let manifest = SeedManifest(seedVersion: 2, sources: [], licenses: [])

    private func seed(_ words: [SeedWord], version: Int) -> SeedWords {
        SeedWords(sourceID: "ngsl-wiktionary", version: version, words: words)
    }

    private func item(_ lemma: String, _ translation: String, meanings: [WordMeaning]? = nil) -> SeedWord {
        SeedWord(lemma: lemma, translation: translation, partOfSpeech: meanings?.first?.partOfSpeech ?? "adjective",
                 meanings: meanings, definition: nil, ipa: nil, level: "A2", frequencyRank: 10, examples: nil)
    }

    @Test func meaningsSurviveStorageAndAreSearchable() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let book = Word(lemma: "book", translation: "книга", partOfSpeech: "noun", meanings: [
            WordMeaning(partOfSpeech: "noun", translation: "книга"),
            WordMeaning(partOfSpeech: "verb", translation: "бронировать"),
        ], origin: .builtin, createdAt: clock.now)
        container.words.insert(book)
        try container.persistence.save()

        let stored = try #require(try container.words.word(id: book.id))
        #expect(stored.meanings.map(\.translation) == ["книга", "бронировать"])
        #expect(try container.words.search("бронировать", limit: 5).map(\.lemma) == ["book"])
    }

    @Test func refreshUpdatesUntouchedWordsAndKeepsEditedOnes() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let importer = SeedDataImporter(words: container.words, persistence: container.persistence)
        try importer.importWords(seed([item("able", "способный, умелый, компетентный"), item("fine", "хороший")], version: 1),
                                 manifest: manifest, now: clock.now)
        var fine = try #require(try container.words.words(normalizedLemma: "fine").first)
        // Пользователь поправил перевод: `updatedAt` позже `createdAt`.
        fine.translation = "мой перевод"
        fine.updatedAt = clock.now.addingTimeInterval(60)
        try container.words.upsert(fine)
        try container.persistence.save()

        let result = try importer.refresh(seed([
            item("able", "способный, талантливый", meanings: [
                WordMeaning(partOfSpeech: "adjective", translation: "способный, талантливый"),
                WordMeaning(partOfSpeech: "verb", translation: "мочь"),
            ]),
            item("fine", "хороший, отличный"),
        ], version: 2), manifest: manifest, startedWordIDs: [], now: clock.now)

        let able = try #require(try container.words.words(normalizedLemma: "able").first)
        #expect(able.translation == "способный, талантливый")
        #expect(able.meanings.count == 2)
        #expect(try container.words.words(normalizedLemma: "fine").first?.translation == "мой перевод")
        #expect(result == SeedDataImporter.RefreshResult(updated: 1, added: 0, removed: 0))
    }

    @Test func refreshAddsNewWordsAndRemovesOnlyUnstartedDroppedOnes() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let importer = SeedDataImporter(words: container.words, persistence: container.persistence)
        try importer.importWords(seed([item("all", "все"), item("each", "каждый"), item("able", "способный")], version: 1),
                                 manifest: manifest, now: clock.now)
        let each = try #require(try container.words.words(normalizedLemma: "each").first)

        let result = try importer.refresh(seed([item("able", "способный"), item("abandon", "оставлять")], version: 2),
                                          manifest: manifest, startedWordIDs: [each.id], now: clock.now)

        #expect(try container.words.words(normalizedLemma: "all").isEmpty)
        #expect(try container.words.words(normalizedLemma: "each").count == 1)
        #expect(try container.words.words(normalizedLemma: "abandon").count == 1)
        #expect(result.added == 1)
        #expect(result.removed == 1)
    }

    @Test func editingTranslationUpdatesTheFirstMeaning() throws {
        let container = try AppContainer.inMemory(clock: clock)
        var word = Word(lemma: "book", translation: "книга", meanings: [
            WordMeaning(partOfSpeech: "noun", translation: "книга"),
            WordMeaning(partOfSpeech: "verb", translation: "бронировать"),
        ], origin: .builtin, createdAt: clock.now)
        container.words.insert(word)
        try container.persistence.save()

        word.translation = "книжка"
        try container.wordEditor.update(word)

        let stored = try #require(try container.words.word(id: word.id))
        #expect(stored.meanings.map(\.translation) == ["книжка", "бронировать"])
    }
}
