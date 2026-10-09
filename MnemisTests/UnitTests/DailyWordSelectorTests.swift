import Testing
import Foundation
@testable import Mnemis

struct DailyWordSelectorTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeWords() -> [Word] {
        [
            Word(lemma: "accomplish", level: "B1", frequencyRank: 1200, origin: .builtin, createdAt: now),
            Word(lemma: "achieve", level: "A2", frequencyRank: 900, origin: .builtin, createdAt: now),
            Word(lemma: "diligent", level: "B2", frequencyRank: 3400, origin: .builtin, createdAt: now),
        ]
    }

    private func progress(for word: Word, status: LearningStatus) -> WordProgress {
        var progress = WordProgress(wordID: word.id, createdAt: now)
        progress.status = status
        return progress
    }

    @Test func sameDayAlwaysGivesSameWord() {
        let words = makeWords()
        let first = DailyWordSelector.select(dayID: "2026-10-08", candidates: words, progress: [], previouslyAssigned: [])
        let second = DailyWordSelector.select(dayID: "2026-10-08", candidates: words, progress: [], previouslyAssigned: [])

        #expect(first != nil)
        #expect(first?.id == second?.id)
    }

    @Test func masteredAndSuspendedWordsAreNeverChosen() {
        let words = makeWords()
        let progress = [
            self.progress(for: words[0], status: .known),
            self.progress(for: words[1], status: .remembered),
        ]

        for day in 1...15 {
            let chosen = DailyWordSelector.select(
                dayID: String(format: "2026-10-%02ld", day),
                candidates: words,
                progress: progress,
                previouslyAssigned: []
            )
            #expect(chosen?.id == words[2].id)
        }
    }

    @Test func previouslyAssignedWordsAreNotRepeated() {
        let words = makeWords()
        let assigned = Set(words.dropLast().map(\.id))

        let chosen = DailyWordSelector.select(dayID: "2026-10-08", candidates: words, progress: [], previouslyAssigned: assigned)

        #expect(chosen?.id == words.last?.id)
    }

    @Test func exhaustedDictionaryReturnsNil() {
        let words = makeWords()
        let chosen = DailyWordSelector.select(
            dayID: "2026-10-08",
            candidates: words,
            progress: [],
            previouslyAssigned: Set(words.map(\.id))
        )
        #expect(chosen == nil)
    }

    @Test func cachedAPIWordsAreNeverDailyWords() {
        let cached = Word(lemma: "serendipity", origin: .api, createdAt: now)
        let chosen = DailyWordSelector.select(dayID: "2026-10-08", candidates: [cached], progress: [], previouslyAssigned: [])
        #expect(chosen == nil)
    }

    @Test func prefersUserLevelWhenAvailable() {
        let words = makeWords()
        for day in 1...10 {
            let chosen = DailyWordSelector.select(
                dayID: String(format: "2026-10-%02ld", day),
                candidates: words,
                progress: [],
                previouslyAssigned: [],
                preferredLevel: "A2"
            )
            #expect(chosen?.level == "A2")
        }
    }

    @Test func fallsBackToAnyLevelWhenNoWordMatches() {
        let chosen = DailyWordSelector.select(
            dayID: "2026-10-08",
            candidates: makeWords(),
            progress: [],
            previouslyAssigned: [],
            preferredLevel: "C2"
        )
        #expect(chosen != nil)
    }

    @Test func hashIsStableAcrossCalls() {
        #expect(DailyWordSelector.fnv1a("2026-10-08") == DailyWordSelector.fnv1a("2026-10-08"))
        #expect(DailyWordSelector.fnv1a("2026-10-08") != DailyWordSelector.fnv1a("2026-10-09"))
    }
}
