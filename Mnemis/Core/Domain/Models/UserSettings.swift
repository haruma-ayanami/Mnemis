import Foundation

/// Уровень по шкале CEFR, от A1 до C1 (ABOUT.md, раздел 13). Совпадает с `Word.level`.
enum LanguageLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    var id: String { rawValue }

    /// Следующий уровень по шкале. На C1 возвращает nil.
    var next: LanguageLevel? {
        switch self {
        case .a1: .a2
        case .a2: .b1
        case .b1: .b2
        case .b2: .c1
        case .c1: nil
        }
    }

    /// Уровень из сохранённой строки. Неизвестные значения (например, старый «IELTS») читаются как B1.
    static func stored(_ raw: String) -> LanguageLevel {
        LanguageLevel(rawValue: raw) ?? .b1
    }
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
    /// Показывать фразы дня (идиомы и предложения из личного списка) на экране Today.
    var phrasesInToday: Bool = true
    var onboardingCompleted: Bool = false

    static let newWordsRange = 1...20
}
