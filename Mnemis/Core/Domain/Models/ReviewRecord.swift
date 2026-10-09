import Foundation

/// Одна попытка повторения. Хранится отдельно от текущего прогресса: нужна для статистики,
/// streak и будущей миграции алгоритма (ARCHITECTURE.md, раздел 3).
struct ReviewRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    var wordID: UUID
    var reviewedAt: Date
    var rating: ReviewRating
    var previousIntervalDays: Double
    var scheduledIntervalDays: Double
    var responseDurationMilliseconds: Int?
    var sessionID: UUID?

    init(
        id: UUID = UUID(),
        wordID: UUID,
        reviewedAt: Date,
        rating: ReviewRating,
        previousIntervalDays: Double,
        scheduledIntervalDays: Double,
        responseDurationMilliseconds: Int? = nil,
        sessionID: UUID? = nil
    ) {
        self.id = id
        self.wordID = wordID
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.previousIntervalDays = previousIntervalDays
        self.scheduledIntervalDays = scheduledIntervalDays
        self.responseDurationMilliseconds = responseDurationMilliseconds
        self.sessionID = sessionID
    }
}
