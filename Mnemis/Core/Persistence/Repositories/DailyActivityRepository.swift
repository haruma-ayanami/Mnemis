import Foundation
import SwiftData

/// Сводка активности по дням: одна строка на день вместо чтения всей истории повторений.
@MainActor
struct DailyActivityRepository {
    let context: ModelContext

    func all() throws -> [DailyActivity] {
        try context.fetch(FetchDescriptor<DailyActivityEntity>(sortBy: [SortDescriptor(\.dayStart)])).map(\.domain)
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<DailyActivityEntity>())
    }

    /// Учитывает одну оценку в её локальный день.
    func recordReview(correct: Bool, dayID: String, dayStart: Date) throws {
        if let existing = try entity(forDay: dayID) {
            existing.reviewCount += 1
            if correct { existing.correctCount += 1 }
        } else {
            context.insert(DailyActivityEntity(DailyActivity(
                localDayID: dayID,
                dayStart: dayStart,
                reviewCount: 1,
                correctCount: correct ? 1 : 0
            )))
        }
    }

    /// Пересчитывает сводку по всей истории. Нужно один раз, когда сводки ещё нет.
    func rebuild(from reviews: [ReviewRecord], calendar: Calendar) throws {
        for entity in try context.fetch(FetchDescriptor<DailyActivityEntity>()) {
            context.delete(entity)
        }

        var byDay: [String: DailyActivity] = [:]
        for review in reviews {
            let dayID = LocalDay.id(for: review.reviewedAt, calendar: calendar)
            var entry = byDay[dayID] ?? DailyActivity(
                localDayID: dayID,
                dayStart: LocalDay.start(of: review.reviewedAt, calendar: calendar),
                reviewCount: 0,
                correctCount: 0
            )
            entry.reviewCount += 1
            if review.rating.isCorrect { entry.correctCount += 1 }
            byDay[dayID] = entry
        }
        for activity in byDay.values {
            context.insert(DailyActivityEntity(activity))
        }
    }

    private func entity(forDay dayID: String) throws -> DailyActivityEntity? {
        try context.fetch(
            FetchDescriptor<DailyActivityEntity>(predicate: #Predicate { $0.localDayID == dayID })
        ).first
    }
}
