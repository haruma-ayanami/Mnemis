import Foundation
import SwiftData

/// Назначения Daily Word. Хранятся, чтобы слово не менялось в течение дня.
@MainActor
struct DailyWordRepository {
    let context: ModelContext

    func assignment(forDay localDayID: String) throws -> DailyWordAssignment? {
        try context.fetch(
            FetchDescriptor<DailyWordAssignmentEntity>(predicate: #Predicate { $0.localDayID == localDayID })
        ).first?.domain
    }

    func all() throws -> [DailyWordAssignment] {
        try context.fetch(FetchDescriptor<DailyWordAssignmentEntity>()).map(\.domain)
    }

    func insert(_ assignment: DailyWordAssignment) {
        context.insert(DailyWordAssignmentEntity(assignment))
    }
}
