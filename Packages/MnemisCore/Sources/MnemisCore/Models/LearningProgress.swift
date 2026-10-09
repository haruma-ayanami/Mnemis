import Foundation
import SwiftData

/// Личный прогресс пользователя по одному слову (ABOUT.md, разделы 6 и 25).
/// `wordID` ссылается на `Word.id`. Одно слово — одна запись прогресса.
@Model
public final class LearningProgress {
    public var id: UUID
    public var wordID: UUID
    public var status: LearningStatus
    /// Номер шага в текущей цепочке. Сбрасывается при Again.
    public var repetitionCount: Int
    public var correctCount: Int
    public var incorrectCount: Int
    public var difficulty: Double
    public var stability: Double
    /// Текущий интервал в днях.
    public var interval: Double
    public var lastReviewedAt: Date?
    public var nextReviewAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), wordID: UUID, createdAt: Date = .now) {
        let initial = SchedulingState.initial
        self.id = id
        self.wordID = wordID
        self.status = initial.status
        self.repetitionCount = initial.repetitionCount
        self.correctCount = initial.correctCount
        self.incorrectCount = initial.incorrectCount
        self.difficulty = initial.difficulty
        self.stability = initial.stability
        self.interval = initial.interval
        self.lastReviewedAt = initial.lastReviewedAt
        self.nextReviewAt = initial.nextReviewAt
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Снимок состояния для движка повторений.
    public var schedulingState: SchedulingState {
        SchedulingState(
            status: status,
            repetitionCount: repetitionCount,
            correctCount: correctCount,
            incorrectCount: incorrectCount,
            difficulty: difficulty,
            stability: stability,
            interval: interval,
            lastReviewedAt: lastReviewedAt,
            nextReviewAt: nextReviewAt
        )
    }

    /// Переносит результат движка в модель.
    public func apply(_ state: SchedulingState, at date: Date) {
        status = state.status
        repetitionCount = state.repetitionCount
        correctCount = state.correctCount
        incorrectCount = state.incorrectCount
        difficulty = state.difficulty
        stability = state.stability
        interval = state.interval
        lastReviewedAt = state.lastReviewedAt
        nextReviewAt = state.nextReviewAt
        updatedAt = date
    }

    /// Слово нужно повторить: оно в расписании и срок уже наступил.
    public func isDue(at date: Date) -> Bool {
        guard status == .learning || status == .reviewing || status == .remembered,
              let nextReviewAt else { return false }
        return nextReviewAt <= date
    }
}
