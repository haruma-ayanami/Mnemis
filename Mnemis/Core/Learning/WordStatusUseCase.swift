import Foundation

/// Ручные переходы статусов: «Я это знаю», возврат в изучение, приостановка и возобновление.
@MainActor
struct WordStatusUseCase {
    let progress: ProgressRepository
    let persistence: PersistenceController
    let clock: any Clock

    func markKnown(wordID: UUID) throws {
        try update(wordID: wordID) { LearningRules.markKnown($0, now: $1) }
    }

    func restoreToLearning(wordID: UUID) throws {
        try update(wordID: wordID) { LearningRules.restoreToLearning($0, now: $1) }
    }

    func suspend(wordID: UUID) throws {
        try update(wordID: wordID) { LearningRules.suspend($0, now: $1) }
    }

    func resume(wordID: UUID) throws {
        try update(wordID: wordID) { LearningRules.resume($0, now: $1) }
    }

    /// Статус, выбранный вручную (переключатель на карточке идиомы).
    func setStatus(wordID: UUID, to status: LearningStatus) throws {
        try update(wordID: wordID) { LearningRules.setStatus($0, to: status, now: $1) }
    }

    /// Отправляет не начатое слово в колоду, в Practice или на завтра (карточка слова).
    func place(wordID: UUID, as placement: StudyPlacement) throws {
        try update(wordID: wordID) { LearningRules.place($0, as: placement, now: $1) }
    }

    /// Отмена ручного размещения: слово снова не начато, прогресса у него нет.
    func removeFromStudy(wordID: UUID) throws {
        guard let current = try progress.progress(forWordID: wordID), LearningRules.canPlace(current) else { return }
        try progress.delete(wordID: wordID)
        try progress.markWordNotStarted(wordID)
        try persistence.save()
    }

    private func update(wordID: UUID, _ transform: (WordProgress, Date) -> WordProgress) throws {
        let now = clock.now
        let current = try progress.progress(forWordID: wordID) ?? WordProgress(wordID: wordID, createdAt: now)
        try progress.upsert(transform(current, now))
        try persistence.save()
    }
}
