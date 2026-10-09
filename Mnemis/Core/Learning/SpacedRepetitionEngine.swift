import Foundation

/// Алгоритм планирования повторений (ARCHITECTURE.md, раздел 5).
///
/// Реализация чистая: не обращается к SwiftData, сети, UI или системным часам.
/// Время передаётся параметром, поэтому тесты детерминированы. Алгоритм можно заменить (например, на FSRS).
protocol SpacedRepetitionEngine: Sendable {
    func schedule(_ progress: WordProgress, rating: ReviewRating, now: Date) -> WordProgress
}
