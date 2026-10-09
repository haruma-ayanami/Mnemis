import Testing
import Foundation
@testable import Mnemis

struct SearchServiceTests {
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

    @Test func emptyQueryReturnsEverything() {
        #expect(SearchService.search("   ", in: [achieve, achievement, accomplish]).count == 3)
    }

    @Test func prefixMatchesComeBeforeContainsMatches() {
        let result = SearchService.search("achieve", in: [achievement, achieve])
        #expect(result.map(\.lemma) == ["achieve", "achievement"])
    }

    @Test func isCaseAndWhitespaceInsensitiveButKeepsOriginalSpelling() {
        let word = Word(lemma: "Ice  Cream", origin: .builtin, createdAt: Date(timeIntervalSince1970: 0))
        let result = SearchService.search("  ICE   cream ", in: [word])

        #expect(result.map(\.lemma) == ["Ice  Cream"])
    }

    @Test func searchesTranslation() {
        #expect(SearchService.search("добиваться", in: [achieve, accomplish]).map(\.lemma) == ["achieve"])
    }

    @Test func searchesDefinition() {
        #expect(SearchService.search("finish", in: [achieve, accomplish]).map(\.lemma) == ["accomplish"])
    }

    @Test func searchesUserNoteAndUserExamples() {
        var noted = accomplish
        noted.userNote = "for my IELTS goal"
        let userTexts = [achieve.id: ["I want to achieve it this year"]]

        #expect(SearchService.search("ielts", in: [achieve, noted]).map(\.lemma) == ["accomplish"])
        #expect(SearchService.search("this year", in: [achieve, accomplish], userTexts: userTexts).map(\.lemma) == ["achieve"])
    }
}
