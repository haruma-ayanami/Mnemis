import Foundation
import Testing
@testable import Mnemis

/// Поиск и страницы словаря работают по базе: префиксы выше вхождений, регистр и пробелы,
/// перевод, определение, заметка и пользовательские примеры (ARCHITECTURE.md, раздел 10).
@MainActor
struct WordSearchTests {
    let clock = TestClock()

    // Слова хранятся как `let`: вычисляемое свойство давало бы новый `id` при каждом обращении.
    private let achieve = Word(
        lemma: "achieve", translation: "добиваться", definition: "to reach a goal",
        origin: .builtin, createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    private let achievement = Word(
        lemma: "achievement", translation: "достижение",
        origin: .builtin, createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    private let accomplish = Word(
        lemma: "accomplish", translation: "выполнять", definition: "to finish something",
        origin: .builtin, createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    private func makeContainer(_ words: [Word], examples: [ExampleSentence] = []) throws -> AppContainer {
        let container = try AppContainer.inMemory(clock: clock)
        for word in words {
            container.words.insert(word)
        }
        for example in examples {
            container.words.insert(example)
        }
        try container.persistence.save()
        return container
    }

    @Test func emptyQueryReturnsNothing() throws {
        let container = try makeContainer([achieve, achievement, accomplish])
        #expect(try container.words.search("   ", limit: 10).isEmpty)
    }

    @Test func prefixMatchesComeBeforeContainsMatches() throws {
        let container = try makeContainer([achievement, achieve])
        let result = try container.words.search("achieve", limit: 10)
        #expect(result.map(\.lemma) == ["achieve", "achievement"])
    }

    @Test func isCaseAndWhitespaceInsensitiveButKeepsOriginalSpelling() throws {
        let word = Word(lemma: "Ice  Cream", origin: .builtin, createdAt: Date(timeIntervalSince1970: 0))
        let container = try makeContainer([word])

        let result = try container.words.search("  ICE   cream ", limit: 10)

        #expect(result.map(\.lemma) == ["Ice  Cream"])
    }

    @Test func searchesTranslation() throws {
        let container = try makeContainer([achieve, accomplish])
        #expect(try container.words.search("добиваться", limit: 10).map(\.lemma) == ["achieve"])
    }

    @Test func searchesDefinition() throws {
        let container = try makeContainer([achieve, accomplish])
        #expect(try container.words.search("finish", limit: 10).map(\.lemma) == ["accomplish"])
    }

    @Test func searchesUserNoteAndUserExamples() throws {
        var noted = accomplish
        noted.userNote = "for my IELTS goal"
        let example = ExampleSentence(
            wordID: achieve.id,
            sentence: "I want to achieve it this year",
            isUserCreated: true,
            createdAt: clock.now
        )
        let container = try makeContainer([achieve, noted], examples: [example])

        #expect(try container.words.search("ielts", limit: 10).map(\.lemma) == ["accomplish"])
        #expect(try container.words.search("this year", limit: 10).map(\.lemma) == ["achieve"])
    }

    @Test func pagesFollowAlphabeticalOrder() throws {
        let container = try makeContainer([achievement, achieve, accomplish])

        let first = try container.words.page(offset: 0, limit: 2)
        let second = try container.words.page(offset: 2, limit: 2)

        #expect(first.map(\.lemma) == ["accomplish", "achieve"])
        #expect(second.map(\.lemma) == ["achievement"])
    }

    @Test func startedWordsAreNotInNotStartedPage() throws {
        let container = try makeContainer([achieve, accomplish])
        try container.progress.upsert(WordProgress(wordID: achieve.id, createdAt: clock.now))
        try container.persistence.save()

        let notStarted = try container.words.page(offset: 0, limit: 10, onlyNotStarted: true)

        #expect(notStarted.map(\.lemma) == ["accomplish"])
        #expect(try container.words.countNotStarted() == 1)
    }
}
