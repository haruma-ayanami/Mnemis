import Foundation

/// Состав учебной сессии (ARCHITECTURE.md, раздел 6).
/// Повторения и новые слова — разные очереди: дневной лимит новых слов никогда не режет повторения.
enum LearningSession {
    /// - Parameters:
    ///   - dailyWordID: Daily Word дня. Входит в лимит новых слов и идёт первым среди них.
    ///   - newWordsPerDay: лимит новых слов из настроек.
    ///   - startedToday: сколько новых слов уже начато сегодня.
    static func queue(
        words: [Word],
        progress: [WordProgress],
        dailyWordID: UUID?,
        newWordsPerDay: Int,
        startedToday: Int,
        now: Date
    ) -> [Word] {
        let wordsByID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let due = ReviewScheduler.dueProgress(progress, at: now).compactMap { wordsByID[$0.wordID] }

        let remaining = max(0, newWordsPerDay - startedToday)
        let startedIDs = Set(progress.map(\.wordID))
        let fresh = words
            .filter { !startedIDs.contains($0.id) && $0.origin != .api }
            .sorted { lhs, rhs in
                // Daily Word первым, затем частотность, затем алфавит.
                if lhs.id == dailyWordID { return rhs.id != dailyWordID }
                if rhs.id == dailyWordID { return false }
                return (lhs.frequencyRank ?? .max, lhs.lemma) < (rhs.frequencyRank ?? .max, rhs.lemma)
            }
            .prefix(remaining)

        return due + fresh
    }

    /// Сколько новых слов уже начато в локальный день.
    static func startedToday(progress: [WordProgress], now: Date, calendar: Calendar) -> Int {
        let start = LocalDay.start(of: now, calendar: calendar)
        return progress.filter { ($0.introducedAt ?? .distantPast) >= start }.count
    }
}
