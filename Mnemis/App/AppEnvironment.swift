import Foundation
import SwiftData
import MnemisCore

/// Сборка хранилища и загрузка встроенного словаря при запуске.
enum AppEnvironment {
    static func makeContainer() -> ModelContainer {
        do {
            return try MnemisStore.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// Загружает встроенный словарь. Импорт идемпотентен, поэтому безопасен при каждом запуске.
    static func bootstrap(in context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
            assertionFailure("words.json is missing from the bundle")
            return
        }
        do {
            try WordImporter().importSeed(from: url, into: context)
        } catch {
            assertionFailure("Built-in dictionary import failed: \(error)")
        }
    }
}
