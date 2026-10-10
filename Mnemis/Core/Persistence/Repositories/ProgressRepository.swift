import Foundation
import SwiftData

/// Личный прогресс по словам. Не более одной записи на слово.
@MainActor
struct ProgressRepository {
    let context: ModelContext

    func all() throws -> [WordProgress] {
        try context.fetch(FetchDescriptor<WordProgressEntity>()).map(\.domain)
    }

    /// Записи, которые пора повторить. Фильтр делает база по индексу: весь прогресс не читаем.
    func due(at now: Date) throws -> [WordProgress] {
        try context.fetch(FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { $0.isSchedulable && $0.dueAt <= now }
        )).map(\.domain)
    }

    func countDue(at now: Date) throws -> Int {
        try context.fetchCount(FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { $0.isSchedulable && $0.dueAt <= now }
        ))
    }

    /// Повторения, запланированные в интервале (start, end). Для строки «скоро» на экране обучения.
    func countScheduled(after start: Date, before end: Date) throws -> Int {
        try context.fetchCount(FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { $0.isSchedulable && $0.dueAt > start && $0.dueAt < end }
        ))
    }

    /// Ближайшая будущая дата повторения, как `ReviewScheduler.nextReviewDate`.
    func nextReviewDate(after now: Date) throws -> Date? {
        let farFuture = Date.distantFuture
        var descriptor = FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { $0.isSchedulable && $0.dueAt > now && $0.dueAt < farFuture },
            sortBy: [SortDescriptor(\.dueAt)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.dueAt
    }

    /// Освоенные слова: «remembered» и «known».
    func countMastered() throws -> Int {
        try context.fetchCount(FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.isMastered }))
    }

    func count(status: LearningStatus) throws -> Int {
        let raw = status.rawValue
        return try context.fetchCount(FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.statusRaw == raw }))
    }

    /// Сколько слов введено в учёт с даты `start`; без даты — за всё время.
    func countIntroduced(since start: Date?) throws -> Int {
        if let start {
            return try context.fetchCount(FetchDescriptor<WordProgressEntity>(
                predicate: #Predicate { $0.introducedSortKey >= start }
            ))
        }
        let never = Date.distantPast
        return try context.fetchCount(FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { $0.introducedSortKey > never }
        ))
    }

    /// Слова, которые освоены: «remembered» или «known».
    func masteredWordIDs() throws -> [UUID] {
        try context.fetch(FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.isMastered })).map(\.wordID)
    }

    func wordIDs(status: LearningStatus) throws -> [UUID] {
        let raw = status.rawValue
        return try context.fetch(FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { $0.statusRaw == raw }
        )).map(\.wordID)
    }

    /// Статусы только для нужных слов: список читает статусы строк, которые видны на экране.
    func statuses(forWordIDs ids: [UUID]) throws -> [UUID: LearningStatus] {
        guard !ids.isEmpty else { return [:] }
        let rows = try context.fetch(FetchDescriptor<WordProgressEntity>(
            predicate: #Predicate { ids.contains($0.wordID) }
        ))
        return Dictionary(rows.map { ($0.wordID, $0.status) }, uniquingKeysWith: { first, _ in first })
    }

    /// Пересчитывает производные поля у всех записей. Нужно один раз после обновления схемы.
    func refreshDerivedFields() throws {
        for entity in try context.fetch(FetchDescriptor<WordProgressEntity>()) {
            entity.apply(entity.domain)
        }
    }

    func progress(forWordID wordID: UUID) throws -> WordProgress? {
        try context.fetch(
            FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.wordID == wordID })
        ).first?.domain
    }

    /// Удаляет прогресс слова: вызывается вместе с удалением самого слова.
    func delete(wordID: UUID) throws {
        for entity in try context.fetch(FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.wordID == wordID })) {
            context.delete(entity)
        }
    }

    func upsert(_ progress: WordProgress) throws {
        let wordID = progress.wordID
        let existing = try context.fetch(
            FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.wordID == wordID })
        ).first
        if let existing {
            existing.apply(progress)
        } else {
            context.insert(WordProgressEntity(progress))
            try markWordStarted(wordID)
        }
    }

    /// Слово начато: оно уходит из очереди новых слов. Флаг на слове позволяет не читать весь прогресс.
    func markWordStarted(_ wordID: UUID) throws {
        let word = try context.fetch(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.id == wordID })).first
        word?.isStarted = true
    }
}
