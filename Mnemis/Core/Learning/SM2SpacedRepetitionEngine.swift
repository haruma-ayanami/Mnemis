import Foundation

/// Упрощённый SM-2 с шагами обучения (ABOUT.md, раздел 35).
struct SM2SpacedRepetitionEngine: SpacedRepetitionEngine {
    /// Интервалы первых показов в днях. Дальше интервал считается через difficulty.
    static let learningSteps: [Double] = [1, 3]
    /// Easy на самом первом показе.
    static let easyFirstStepDays: Double = 4
    /// Интервал после Again: 10 минут, в днях.
    static let againDelayDays: Double = 10.0 / 1440.0
    /// Интервал, с которого слово считается `remembered`.
    static let rememberedThresholdDays: Double = 21
    static let difficultyRange: ClosedRange<Double> = 1.3...3.0
    static let secondsPerDay: Double = 86_400

    func schedule(_ progress: WordProgress, rating: ReviewRating, now: Date) -> WordProgress {
        // Известные и приостановленные слова не планируются.
        guard LearningRules.isSchedulable(progress.status) else { return progress }

        let step = progress.repetitionCount
        let inLadder = step < Self.learningSteps.count
        var difficulty = progress.difficulty
        var interval: Double

        switch rating {
        case .again:
            interval = Self.againDelayDays
            difficulty -= 0.2
        case .hard:
            interval = inLadder ? Self.learningSteps[step] : progress.intervalDays * 1.2
            difficulty -= 0.15
        case .good:
            interval = inLadder ? Self.learningSteps[step] : progress.intervalDays * progress.difficulty
        case .easy:
            if inLadder {
                interval = step == 0 ? Self.easyFirstStepDays : Self.learningSteps[step] * 1.3
            } else {
                interval = progress.intervalDays * progress.difficulty * 1.3
            }
            difficulty += 0.15
        }

        difficulty = min(max(difficulty, Self.difficultyRange.lowerBound), Self.difficultyRange.upperBound)
        interval = max(interval, Self.againDelayDays)

        var next = progress
        next.status = nextStatus(from: progress.status, rating: rating, interval: interval)
        // Again начинает цепочку шагов заново.
        next.repetitionCount = rating == .again ? 0 : step + 1
        if rating.isCorrect {
            next.correctCount += 1
        } else {
            next.incorrectCount += 1
        }
        next.difficulty = difficulty
        next.intervalDays = interval
        next.stability = interval // Заглушка под FSRS-подобную модель стабильности.
        next.lastReviewedAt = now
        next.nextReviewAt = now.addingTimeInterval(interval * Self.secondsPerDay)
        next.introducedAt = progress.introducedAt ?? now
        next.updatedAt = now
        return next
    }

    private func nextStatus(from status: LearningStatus, rating: ReviewRating, interval: Double) -> LearningStatus {
        let isLongEnough = interval >= Self.rememberedThresholdDays
        switch status {
        case .new, .learning:
            return rating.isPassing ? .reviewing : .learning
        case .reviewing:
            if rating == .again { return .learning }
            return rating.isPassing && isLongEnough ? .remembered : .reviewing
        case .remembered:
            if rating == .again || rating == .hard { return .reviewing }
            return isLongEnough ? .remembered : .reviewing
        case .known, .suspended:
            return status
        }
    }
}
