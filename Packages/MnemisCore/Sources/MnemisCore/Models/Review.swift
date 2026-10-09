import Foundation
import SwiftData

/// Запись истории повторений (ABOUT.md, раздел 25). Нужна для статистики и streak.
@Model
public final class Review {
    public var id: UUID
    public var wordID: UUID
    public var rating: ReviewRating
    public var reviewedAt: Date
    public var previousInterval: Double
    public var newInterval: Double

    public init(
        id: UUID = UUID(),
        wordID: UUID,
        rating: ReviewRating,
        reviewedAt: Date,
        previousInterval: Double,
        newInterval: Double
    ) {
        self.id = id
        self.wordID = wordID
        self.rating = rating
        self.reviewedAt = reviewedAt
        self.previousInterval = previousInterval
        self.newInterval = newInterval
    }
}
