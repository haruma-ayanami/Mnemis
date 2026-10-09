import Foundation

/// Состояние слова для планирования. Чистое значение без SwiftData:
/// движок работает с ним, а `LearningProgress` лишь хранит его.
public struct SchedulingState: Equatable, Sendable {
    public var status: LearningStatus
    public var repetitionCount: Int
    public var correctCount: Int
    public var incorrectCount: Int
    public var difficulty: Double
    public var stability: Double
    /// Интервал в днях.
    public var interval: Double
    public var lastReviewedAt: Date?
    public var nextReviewAt: Date?

    public init(
        status: LearningStatus,
        repetitionCount: Int,
        correctCount: Int,
        incorrectCount: Int,
        difficulty: Double,
        stability: Double,
        interval: Double,
        lastReviewedAt: Date?,
        nextReviewAt: Date?
    ) {
        self.status = status
        self.repetitionCount = repetitionCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.difficulty = difficulty
        self.stability = stability
        self.interval = interval
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt
    }

    /// Состояние нового слова до первого показа.
    public static let initial = SchedulingState(
        status: .new,
        repetitionCount: 0,
        correctCount: 0,
        incorrectCount: 0,
        difficulty: 2.5,
        stability: 0,
        interval: 0,
        lastReviewedAt: nil,
        nextReviewAt: nil
    )
}
