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

    private func update(wordID: UUID, _ transform: (WordProgress, Date) -> WordProgress) throws {
        let now = clock.now
        let current = try progress.progress(forWordID: wordID) ?? WordProgress(wordID: wordID, createdAt: now)
        try progress.upsert(transform(current, now))
        try persistence.save()
    }
}
