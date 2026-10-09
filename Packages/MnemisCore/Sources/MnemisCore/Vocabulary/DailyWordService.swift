import Foundation
import SwiftData

/// Получает слово дня: берёт уже назначенное на сегодня или назначает новое и сохраняет назначение.
public struct DailyWordService {
    let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func word(for date: Date = .now, preferredLevel: String? = nil, calendar: Calendar = .current) throws -> Word? {
        let key = DayKey.make(for: date, calendar: calendar)

        // Назначение на этот день уже сделано: возвращаем то же слово.
        let assignment = try context.fetch(
            FetchDescriptor<DailyWord>(predicate: #Predicate { $0.dayKey == key })
        ).first
        if let assignment, let existing = try fetchWord(id: assignment.wordID) {
            return existing
        }

        let words = try context.fetch(FetchDescriptor<Word>())
        let progress = try context.fetch(FetchDescriptor<LearningProgress>())
        // Освоенные и известные слова не выдаём снова (раздел 5).
        let excluded = Set(
            progress
                .filter { $0.status == .known || $0.status == .remembered }
                .map(\.wordID)
        )

        guard let chosen = DailyWordSelector.select(
            dayKey: key,
            candidates: words.filter { $0.origin == .builtin || $0.origin == .user },
            excluded: excluded,
            preferredLevel: preferredLevel
        ) else { return nil }

        context.insert(DailyWord(dayKey: key, wordID: chosen.id, assignedAt: date))
        return chosen
    }

    private func fetchWord(id: UUID) throws -> Word? {
        try context.fetch(FetchDescriptor<Word>(predicate: #Predicate { $0.id == id })).first
    }
}
