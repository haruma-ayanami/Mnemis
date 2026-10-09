import Testing
import Foundation
@testable import MnemisCore

struct SearchServiceTests {
    private let achieve = Word(lemma: "achieve", translation: "добиваться", definition: "to reach a goal")
    private let achievement = Word(lemma: "achievement", translation: "достижение")
    private let accomplish = Word(lemma: "accomplish", translation: "выполнять", definition: "to finish something")

    @Test func emptyQueryReturnsEverything() {
        let result = SearchService.search("   ", in: [achieve, achievement, accomplish])
        #expect(result.count == 3)
    }

    @Test func prefixMatchesComeBeforeContainsMatches() {
        let result = SearchService.search("achieve", in: [achievement, achieve])

        #expect(result.map(\.lemma) == ["achieve", "achievement"])
    }

    @Test func searchesTranslation() {
        let result = SearchService.search("добиваться", in: [achieve, accomplish])
        #expect(result.map(\.lemma) == ["achieve"])
    }

    @Test func searchesDefinition() {
        let result = SearchService.search("finish", in: [achieve, accomplish])
        #expect(result.map(\.lemma) == ["accomplish"])
    }

    @Test func searchesUserNotesAndExamples() {
        let userTexts = [accomplish.id: ["My IELTS goal for this year"]]
        let result = SearchService.search("ielts", in: [achieve, accomplish], userTexts: userTexts)

        #expect(result.map(\.lemma) == ["accomplish"])
    }

    @Test func isCaseInsensitive() {
        let result = SearchService.search("ACHIEVE", in: [achieve])
        #expect(result.count == 1)
    }
}
