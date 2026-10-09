import Foundation
import SwiftData

/// История повторений. Записи только добавляются и не переписываются при пересчёте прогресса.
@MainActor
struct ReviewRepository {
    let context: ModelContext

    func all() throws -> [ReviewRecord] {
        try context.fetch(FetchDescriptor<ReviewRecordEntity>()).map(\.domain)
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<ReviewRecordEntity>())
    }

    func append(_ record: ReviewRecord) {
        context.insert(ReviewRecordEntity(record))
    }
}
