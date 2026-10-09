import Foundation
import Observation

/// Сначала предлагаем вход, затем настройки для новых пользователей и тех, кто пропустил вход (ABOUT.md, раздел 37).
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case account
    case level
    case pace
    case notifications
}

@Observable
@MainActor
final class OnboardingViewModel {
    var step: OnboardingStep = .welcome
    var level: LanguageLevel = .b1
    var newWordsPerDay: Int = 5
    var remindersOn = true
    private(set) var errorMessage: String?

    /// Вход необязателен: шаг можно пропустить кнопкой «Continue without account».
    let account: AccountViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        self.account = AccountViewModel(account: container.account)
        if let settings = try? container.settings.load() {
            level = settings.proficiencyLevel
            newWordsPerDay = settings.newWordsPerDay
        }
    }

    /// Примерная длительность дневной сессии в минутах.
    var estimatedMinutes: Int { Int((Double(newWordsPerDay) * 1.5 + 4).rounded()) }

    func next() {
        switch step {
        case .welcome: step = .account
        case .account: step = .level
        case .level: step = .pace
        case .pace:
            if remindersOn {
                step = .notifications
            } else {
                finish(notificationsAllowed: false)
            }
        case .notifications: finish(notificationsAllowed: false)
        }
    }

    func back() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func setPace(_ value: Int) {
        newWordsPerDay = min(max(value, UserSettings.newWordsRange.lowerBound), UserSettings.newWordsRange.upperBound)
    }

    /// Показывает системный запрос, затем завершает онбординг.
    func allowNotifications() async {
        let allowed = await container.notifications.requestAuthorization()
        finish(notificationsAllowed: allowed)
    }

    func finish(notificationsAllowed: Bool) {
        do {
            try container.settings.update { settings in
                settings.proficiencyLevel = level
                settings.newWordsPerDay = newWordsPerDay
                settings.dailyReminderEnabled = notificationsAllowed
                settings.onboardingCompleted = true
            }
            container.router.isOnboarded = true
            Task { await container.refreshNotifications() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
