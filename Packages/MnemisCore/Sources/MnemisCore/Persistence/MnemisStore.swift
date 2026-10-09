import Foundation
import SwiftData

/// Хранилище SwiftData. Единственное место, где перечислены все модели.
public enum MnemisStore {
    public static var models: [any PersistentModel.Type] {
        [
            Word.self,
            LearningProgress.self,
            Review.self,
            DailyWord.self,
            UserExample.self,
            UserNote.self,
        ]
    }

    /// - Parameter inMemory: `true` для тестов и SwiftUI Preview.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
