import Foundation

/// Уровень владения языком (ABOUT.md, раздел 13). Совпадает с `Word.level`.
enum LanguageLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case ielts = "IELTS"

    var id: String { rawValue }
}

enum ThemePreference: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Настройки одного локального профиля. Хранятся в SwiftData, а не в UserDefaults.
struct UserSettings: Equatable, Sendable {
    var learningLanguage: LanguageCode = .en
    var translationLanguage: LanguageCode = .ru
    var proficiencyLevel: LanguageLevel = .b1
    var newWordsPerDay: Int = 5
    /// Главный переключатель уведомлений.
    var dailyReminderEnabled: Bool = false
    /// Время слова дня в минутах от полуночи по локальному времени.
    var dailyReminderMinutes: Int = 9 * 60
    var notifyWordOfDay: Bool = true
    var notifyReviews: Bool = true
    var notifyStreak: Bool = true
    /// Дни недели, биты 0…6 = понедельник…воскресенье.
    var notificationWeekdays: Int = 0b1111111
    var maxNotificationsPerDay: Int = 2
    var preferredTheme: ThemePreference = .system
    var soundEnabled: Bool = true
    var onboardingCompleted: Bool = false

    static let newWordsRange = 1...20
}
