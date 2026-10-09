import Foundation

/// Расписание повторений: какие слова due и когда будет следующее повторение.
/// Не меняет прогресс, только читает его.
enum ReviewScheduler {
    /// Слова, которые нужно повторить сейчас. Самые просроченные идут первыми.
    static func dueProgress(_ progress: [WordProgress], at now: Date) -> [WordProgress] {
        progress
            .filter { $0.isDue(at: now) }
            .sorted { ($0.nextReviewAt ?? .distantPast) < ($1.nextReviewAt ?? .distantPast) }
    }

    /// Ближайший момент, когда появится повторение. Нужен для пустого состояния «всё сделано».
    static func nextReviewDate(in progress: [WordProgress], after now: Date) -> Date? {
        progress
            .filter { LearningRules.isSchedulable($0.status) }
            .compactMap(\.nextReviewAt)
            .filter { $0 > now }
            .min()
    }
}
