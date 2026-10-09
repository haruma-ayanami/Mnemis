import Foundation

/// Чтение и сохранение настроек профиля.
@MainActor
struct SettingsUseCase {
    let settings: SettingsRepository
    let persistence: PersistenceController

    func load() throws -> UserSettings {
        try settings.load()
    }

    /// Меняет настройки и сразу сохраняет их.
    func update(_ change: (inout UserSettings) -> Void) throws {
        var current = try settings.load()
        change(&current)
        current.newWordsPerDay = min(max(current.newWordsPerDay, UserSettings.newWordsRange.lowerBound), UserSettings.newWordsRange.upperBound)
        try settings.save(current)
        try persistence.save()
    }
}
