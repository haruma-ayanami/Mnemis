import Foundation
import SwiftData

/// Связывает движок повторений с хранилищем: применяет оценку и пишет историю.
public struct ReviewService {
    let engine: any SpacedRepetitionEngine
    let context: ModelContext

    public init(engine: any SpacedRepetitionEngine = SM2SpacedRepetitionEngine(), context: ModelContext) {
        self.engine = engine
        self.context = context
    }

    /// Применяет оценку к слову. Прогресс создаётся, если его ещё нет.
    @discardableResult
    public func rate(wordID: UUID, rating: ReviewRating, now: Date = .now) throws -> LearningProgress {
        let progress = try progress(for: wordID, now: now)
        let previousInterval = progress.interval
        let next = engine.schedule(progress.schedulingState, rating: rating, now: now)

        progress.apply(next, at: now)
        context.insert(Review(
            wordID: wordID,
            rating: rating,
            reviewedAt: now,
            previousInterval: previousInterval,
            newInterval: next.interval
        ))
        return progress
    }

    /// Пользователь отметил слово как известное (кнопка «Я это знаю»). Повторения больше не планируются.
    public func markKnown(wordID: UUID, now: Date = .now) throws {
        let progress = try progress(for: wordID, now: now)
        progress.status = .known
        progress.nextReviewAt = nil
        progress.updatedAt = now
    }

    private func progress(for wordID: UUID, now: Date) throws -> LearningProgress {
        let existing = try context.fetch(
            FetchDescriptor<LearningProgress>(predicate: #Predicate { $0.wordID == wordID })
        ).first
        if let existing { return existing }

        let created = LearningProgress(wordID: wordID, createdAt: now)
        context.insert(created)
        return created
    }
}
