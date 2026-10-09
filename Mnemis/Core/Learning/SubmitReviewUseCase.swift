import Foundation

enum ReviewError: Error, Equatable {
    /// Слово известно или приостановлено и в расписание не входит.
    case wordNotSchedulable
}

/// Оценка карточки (ARCHITECTURE.md, раздел 5): прогресс и история записываются одной транзакцией.
@MainActor
struct SubmitReviewUseCase {
    let progress: ProgressRepository
    let reviews: ReviewRepository
    let activity: DailyActivityRepository
    let persistence: PersistenceController
    let engine: any SpacedRepetitionEngine
    let clock: any Clock

    @discardableResult
    func execute(
        wordID: UUID,
        rating: ReviewRating,
        sessionID: UUID? = nil,
        responseDurationMilliseconds: Int? = nil
    ) throws -> WordProgress {
        let now = clock.now
        let current = try progress.progress(forWordID: wordID) ?? WordProgress(wordID: wordID, createdAt: now)
        guard LearningRules.isSchedulable(current.status) else { throw ReviewError.wordNotSchedulable }

        let updated = engine.schedule(current, rating: rating, now: now)

        // Нельзя записать попытку без нового состояния или наоборот: оба изменения уходят в один save().
        try progress.upsert(updated)
        reviews.append(ReviewRecord(
            wordID: wordID,
            reviewedAt: now,
            rating: rating,
            previousIntervalDays: current.intervalDays,
            scheduledIntervalDays: updated.intervalDays,
            responseDurationMilliseconds: responseDurationMilliseconds,
            sessionID: sessionID
        ))
        try activity.recordReview(
            correct: rating.isCorrect,
            dayID: LocalDay.id(for: now, calendar: clock.calendar),
            dayStart: LocalDay.start(of: now, calendar: clock.calendar)
        )
        try persistence.save()
        return updated
    }
}
