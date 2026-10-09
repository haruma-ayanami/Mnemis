import OSLog
import Foundation
import SwiftData

/// Владелец `ModelContainer`. Единственная точка создания хранилища.
/// Сохранение идёт через `save()`: прогресс и история повторений пишутся одной транзакцией.
@MainActor
final class PersistenceController {
    static let models: [any PersistentModel.Type] = [
        WordEntity.self,
        ExampleSentenceEntity.self,
        WordProgressEntity.self,
        ReviewRecordEntity.self,
        DailyWordAssignmentEntity.self,
        UserSettingsEntity.self,
    ]

    let container: ModelContainer

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// - Parameters:
    ///   - storeURL: файл хранилища. Если `nil`, используется стандартное расположение SwiftData.
    ///   - inMemory: хранилище в памяти, для тестов и превью.
    static func make(storeURL: URL? = nil, inMemory: Bool = false) throws -> PersistenceController {
        let schema = Schema(models)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let storeURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return PersistenceController(container: try ModelContainer(for: schema, configurations: [configuration]))
    }

    func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.persistence.error("Save failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}
