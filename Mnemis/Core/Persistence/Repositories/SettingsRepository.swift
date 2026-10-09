import Foundation
import SwiftData

/// Настройки профиля. Одна запись. Если её нет, возвращаются значения по умолчанию.
@MainActor
struct SettingsRepository {
    let context: ModelContext

    func load() throws -> UserSettings {
        try context.fetch(FetchDescriptor<UserSettingsEntity>()).first?.domain ?? UserSettings()
    }

    func save(_ settings: UserSettings) throws {
        if let existing = try context.fetch(FetchDescriptor<UserSettingsEntity>()).first {
            existing.apply(settings)
        } else {
            context.insert(UserSettingsEntity(settings))
        }
    }
}
