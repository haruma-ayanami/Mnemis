import Foundation

/// Ключи настроек в `UserDefaults` (через `@AppStorage`).
enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let level = "level"
    static let dailyNewWordLimit = "dailyNewWordLimit"
}

/// Уровень пользователя (ABOUT.md, раздел 13). Значение совпадает с `Word.level`.
nonisolated enum LanguageLevel: String, CaseIterable, Identifiable, Sendable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case ielts = "IELTS"

    var id: String { rawValue }
    static let defaultValue = LanguageLevel.b1
}
