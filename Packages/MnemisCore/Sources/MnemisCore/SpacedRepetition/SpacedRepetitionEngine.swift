import Foundation

/// Алгоритм планирования повторений (ABOUT.md, раздел 6).
///
/// Реализация должна быть чистой функцией: одинаковый вход — одинаковый выход.
/// Так алгоритм можно заменить (например, на FSRS), не трогая UI и модель данных.
public protocol SpacedRepetitionEngine: Sendable {
    func schedule(_ state: SchedulingState, rating: ReviewRating, now: Date) -> SchedulingState
}
