import Foundation

/// Очередь учебной сессии (ABOUT.md, раздел 29: новые слова + запланированные повторения).
public enum LearnQueue {
    /// Сначала просроченные повторения (самые старые первыми), затем новые слова в пределах дневного лимита.
    /// Новые слова, начатые сегодня, уже входят в лимит.
    public static func make(
        words: [Word],
        progress: [LearningProgress],
        dailyNewLimit: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Word] {
        let wordsByID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let due = progress
            .filter { $0.isDue(at: now) }
            .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
            .compactMap { wordsByID[$0.wordID] }

        let startOfToday = calendar.startOfDay(for: now)
        let startedToday = progress.filter { $0.createdAt >= startOfToday }.count
        let remaining = max(0, dailyNewLimit - startedToday)
        let startedIDs = Set(progress.map(\.wordID))

        let fresh = words
            .filter { !startedIDs.contains($0.id) && $0.origin != .api }
            .sorted { ($0.frequency ?? .max, $0.lemma) < ($1.frequency ?? .max, $1.lemma) }
            .prefix(remaining)

        return due + fresh
    }
}
