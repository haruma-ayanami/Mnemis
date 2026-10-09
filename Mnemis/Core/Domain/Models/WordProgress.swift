import Foundation

/// Состояние изучения слова конкретным пользователем (ARCHITECTURE.md, раздел 3).
/// На одно слово — не больше одной записи. Истории попыток здесь нет: она в `ReviewRecord`.
struct WordProgress: Identifiable, Equatable, Sendable {
    let id: UUID
    let wordID: UUID
    var status: LearningStatus
    /// Номер шага в текущей цепочке повторений. Сбрасывается при Again.
    var repetitionCount: Int
    var correctCount: Int
    var incorrectCount: Int
    var difficulty: Double
    var stability: Double
    var intervalDays: Double
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    /// Когда слово впервые попало в учебную сессию. По этому полю считается дневной лимит новых слов.
    var introducedAt: Date?
    /// Статус до `suspended`, чтобы восстановить его при возврате.
    var suspendedFromStatus: LearningStatus?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), wordID: UUID, createdAt: Date) {
        self.id = id
        self.wordID = wordID
        self.status = .new
        self.repetitionCount = 0
        self.correctCount = 0
        self.incorrectCount = 0
        self.difficulty = 2.5
        self.stability = 0
        self.intervalDays = 0
        self.lastReviewedAt = nil
        self.nextReviewAt = nil
        self.introducedAt = nil
        self.suspendedFromStatus = nil
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Слово в расписании и срок повторения уже наступил.
    func isDue(at date: Date) -> Bool {
        guard LearningRules.isSchedulable(status), let nextReviewAt else { return false }
        return nextReviewAt <= date
    }
}
