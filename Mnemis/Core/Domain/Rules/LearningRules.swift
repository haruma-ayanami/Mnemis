import Foundation

/// Правила переходов между статусами (ARCHITECTURE.md, раздел 4).
/// Чистые функции: получают прогресс и время, возвращают новый прогресс. Без SwiftData и UI.
enum LearningRules {
    /// Слово участвует в очередях и в выборе Daily Word.
    static func isSchedulable(_ status: LearningStatus) -> Bool {
        status != .known && status != .suspended
    }

    /// «Я это знаю»: повторения больше не планируются. Обратимо через `restoreToLearning`.
    static func markKnown(_ progress: WordProgress, now: Date) -> WordProgress {
        guard progress.status != .suspended, progress.status != .known else { return progress }
        var result = progress
        result.status = .known
        result.nextReviewAt = nil
        result.updatedAt = now
        return result
    }

    /// Возвращает слово из `known` в повторение. Оно становится due сразу.
    static func restoreToLearning(_ progress: WordProgress, now: Date) -> WordProgress {
        guard progress.status == .known else { return progress }
        var result = progress
        result.status = .reviewing
        result.intervalDays = 1
        result.nextReviewAt = now
        result.updatedAt = now
        return result
    }

    /// Временно исключает слово из очередей и запоминает прежний статус.
    static func suspend(_ progress: WordProgress, now: Date) -> WordProgress {
        guard progress.status != .suspended else { return progress }
        var result = progress
        result.suspendedFromStatus = progress.status
        result.status = .suspended
        result.nextReviewAt = nil
        result.updatedAt = now
        return result
    }

    /// Возвращает приостановленное слово в прежний статус.
    static func resume(_ progress: WordProgress, now: Date) -> WordProgress {
        guard progress.status == .suspended else { return progress }
        var result = progress
        let restored = progress.suspendedFromStatus ?? .learning
        result.status = restored
        result.suspendedFromStatus = nil
        result.nextReviewAt = isSchedulable(restored) ? now : nil
        result.updatedAt = now
        return result
    }
}
