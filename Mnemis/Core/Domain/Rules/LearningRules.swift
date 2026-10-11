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

    /// Ручное размещение ещё не начатого слова: в колоду на сегодня, в Practice или на завтра.
    /// Во всех случаях слово становится `learning` без единого повторения; интервалы берём у движка.
    static func place(_ progress: WordProgress, as placement: StudyPlacement, now: Date) -> WordProgress {
        var result = progress
        result.status = .learning
        result.suspendedFromStatus = nil
        result.repetitionCount = 0
        result.updatedAt = now
        let day = SM2SpacedRepetitionEngine.secondsPerDay
        switch placement {
        case .today:
            // Попадает в «новые за сегодня» и в очередь сразу: срок повторения уже наступил.
            result.intervalDays = 0
            result.introducedAt = now
            result.nextReviewAt = now
        case .practice:
            // Без расписания: в очередь повторений не попадает, но участвует в упражнениях.
            result.intervalDays = 0
            result.introducedAt = nil
            result.nextReviewAt = nil
        case .later:
            result.intervalDays = SM2SpacedRepetitionEngine.learningSteps[0]
            result.introducedAt = nil
            result.nextReviewAt = now.addingTimeInterval(result.intervalDays * day)
        }
        return result
    }

    /// Можно ли показывать выбор «Today / Practice / Later»: слово не начато или размещено вручную
    /// и ни разу не повторялось.
    static func canPlace(_ progress: WordProgress?) -> Bool {
        guard let progress else { return true }
        switch progress.status {
        case .new: return true
        case .learning: return progress.correctCount + progress.incorrectCount == 0 && progress.repetitionCount == 0
        default: return false
        }
    }

    /// Текущее ручное размещение слова. `nil` — слово не размещено.
    static func placement(of progress: WordProgress?, now: Date) -> StudyPlacement? {
        guard let progress, canPlace(progress), progress.status == .learning else { return nil }
        guard let next = progress.nextReviewAt else { return .practice }
        return next <= now ? .today : .later
    }

    /// Ручной выбор статуса из переключателя идиомы. Интервалы берём у движка повторений,
    /// чтобы слово, выставленное вручную, планировалось так же, как пройденное в сессии.
    static func setStatus(_ progress: WordProgress, to status: LearningStatus, now: Date) -> WordProgress {
        var result = progress
        result.status = status
        result.suspendedFromStatus = nil
        result.updatedAt = now
        let day = SM2SpacedRepetitionEngine.secondsPerDay
        switch status {
        case .new:
            result.nextReviewAt = nil
        case .learning:
            result.repetitionCount = 0
            result.intervalDays = SM2SpacedRepetitionEngine.learningSteps[0]
            result.nextReviewAt = now.addingTimeInterval(result.intervalDays * day)
        case .reviewing:
            result.repetitionCount = SM2SpacedRepetitionEngine.learningSteps.count
            result.intervalDays = SM2SpacedRepetitionEngine.learningSteps.last ?? 1
            result.nextReviewAt = now.addingTimeInterval(result.intervalDays * day)
        case .remembered:
            result.repetitionCount = SM2SpacedRepetitionEngine.learningSteps.count
            result.intervalDays = SM2SpacedRepetitionEngine.rememberedThresholdDays
            result.nextReviewAt = now.addingTimeInterval(result.intervalDays * day)
        case .known:
            result.nextReviewAt = nil
        case .suspended:
            result.suspendedFromStatus = progress.status == .suspended ? progress.suspendedFromStatus : progress.status
            result.nextReviewAt = nil
        }
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
