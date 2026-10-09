import Foundation
import SwiftData

/// Личный прогресс по словам. Не более одной записи на слово.
@MainActor
struct ProgressRepository {
    let context: ModelContext

    func all() throws -> [WordProgress] {
        try context.fetch(FetchDescriptor<WordProgressEntity>()).map(\.domain)
    }

    func progress(forWordID wordID: UUID) throws -> WordProgress? {
        try context.fetch(
            FetchDescriptor<WordProgressEntity>(predicate: #Predicate { $0.wordID == wordID })
        ).first?.domain
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
        }
    }
}
