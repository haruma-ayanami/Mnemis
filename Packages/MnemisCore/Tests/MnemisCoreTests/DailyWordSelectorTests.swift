import Testing
import Foundation
@testable import MnemisCore

struct DailyWordSelectorTests {
    private func makeWords() -> [Word] {
        [
            Word(lemma: "accomplish", level: "B1", frequency: 1200, origin: .builtin),
            Word(lemma: "achieve", level: "A2", frequency: 900, origin: .builtin),
            Word(lemma: "diligent", level: "B2", frequency: 3400, origin: .builtin),
        ]
    }

    @Test func sameDayAlwaysGivesSameWord() {
        let words = makeWords()
        let first = DailyWordSelector.select(dayKey: "2026-10-08", candidates: words, excluded: [])
        let second = DailyWordSelector.select(dayKey: "2026-10-08", candidates: words, excluded: [])

        #expect(first != nil)
        #expect(first?.id == second?.id)
    }

    @Test func excludedWordsAreNeverChosen() {
        let words = makeWords()
        let allButOne = Set(words.dropLast().map(\.id))

        for day in 1...20 {
            let key = String(format: "2026-10-%02ld", day)
            let chosen = DailyWordSelector.select(dayKey: key, candidates: words, excluded: allButOne)
            #expect(chosen?.id == words.last?.id)
        }
    }

    @Test func returnsNilWhenNothingIsEligible() {
        let words = makeWords()
        let chosen = DailyWordSelector.select(
            dayKey: "2026-10-08",
            candidates: words,
            excluded: Set(words.map(\.id))
        )
        #expect(chosen == nil)
    }

    @Test func prefersUserLevelWhenAvailable() {
        let words = makeWords()

        for day in 1...10 {
            let key = String(format: "2026-10-%02ld", day)
            let chosen = DailyWordSelector.select(
                dayKey: key,
                candidates: words,
                excluded: [],
                preferredLevel: "A2"
            )
            #expect(chosen?.level == "A2")
        }
    }

    @Test func fallsBackToAnyLevelWhenNoWordMatches() {
        let chosen = DailyWordSelector.select(
            dayKey: "2026-10-08",
            candidates: makeWords(),
            excluded: [],
            preferredLevel: "C2"
        )
        #expect(chosen != nil)
    }

    @Test func fnv1aIsStableAcrossCalls() {
        #expect(DailyWordSelector.fnv1a("2026-10-08") == DailyWordSelector.fnv1a("2026-10-08"))
        #expect(DailyWordSelector.fnv1a("2026-10-08") != DailyWordSelector.fnv1a("2026-10-09"))
    }
}
