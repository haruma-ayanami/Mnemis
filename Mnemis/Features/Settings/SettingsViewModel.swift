import Foundation
import Observation

/// Настройки профиля, уведомления и список источников с лицензиями (ABOUT.md, раздел 13).
@Observable
@MainActor
final class SettingsViewModel {
    struct SourceInfo: Identifiable, Equatable {
        let id: String
        let name: String
        let licenseName: String
        let licenseText: String
    }

    private(set) var settings = UserSettings()
    private(set) var sources: [SourceInfo] = []
    private(set) var notificationsAuthorized = false
    private(set) var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func load() {
        do {
            settings = try container.settings.load()
            sources = try loadSources()
        } catch {
            errorMessage = error.localizedDescription
        }
        Task { notificationsAuthorized = await container.notifications.isAuthorized() }
    }

    // MARK: - Обучение и вид

    func setLevel(_ level: LanguageLevel) { change { $0.proficiencyLevel = level } }
    func setNewWordsPerDay(_ count: Int) { change { $0.newWordsPerDay = count } }
    func setSound(_ on: Bool) { change { $0.soundEnabled = on } }

    func setTheme(_ theme: ThemePreference) {
        change { $0.preferredTheme = theme }
        container.router.colorScheme = AppContainer.colorScheme(for: theme)
    }

    // MARK: - Уведомления

    /// Главный тумблер. При первом включении показывает системный запрос.
    func setNotificationsEnabled(_ on: Bool) {
        Task {
            if on, !(await container.notifications.isAuthorized()) {
                let allowed = await container.notifications.requestAuthorization()
                notificationsAuthorized = allowed
                guard allowed else {
                    change(refresh: false) { $0.dailyReminderEnabled = false }
                    return
                }
            }
            change { $0.dailyReminderEnabled = on }
        }
    }

    func setNotify(_ kind: NotificationKind, _ on: Bool) {
        change {
            switch kind {
            case .wordOfDay: $0.notifyWordOfDay = on
            case .reviews: $0.notifyReviews = on
            case .streak: $0.notifyStreak = on
            }
        }
    }

    func toggleWeekday(_ index: Int) {
        change { $0.notificationWeekdays ^= (1 << index) }
    }

    func setMaxPerDay(_ count: Int) { change { $0.maxNotificationsPerDay = count } }

    func setWordTime(minutes: Int) {
        change { $0.dailyReminderMinutes = NotificationPlanner.clampToDaytime(minutes) }
    }

    func isNotify(_ kind: NotificationKind) -> Bool {
        switch kind {
        case .wordOfDay: settings.notifyWordOfDay
        case .reviews: settings.notifyReviews
        case .streak: settings.notifyStreak
        }
    }

    func isWeekdayOn(_ index: Int) -> Bool { settings.notificationWeekdays & (1 << index) != 0 }

    /// Строка-сводка под заголовком экрана уведомлений.
    var notificationSummary: String {
        guard settings.dailyReminderEnabled else { return String(localized: "all notifications are off") }
        let active = [settings.notifyWordOfDay, settings.notifyReviews, settings.notifyStreak].filter { $0 }.count
        return "\(active) on · at most \(settings.maxNotificationsPerDay) a day · quiet at night"
    }

    var notificationsRowValue: String {
        guard settings.dailyReminderEnabled else { return String(localized: "off") }
        let active = [settings.notifyWordOfDay, settings.notifyReviews, settings.notifyStreak].filter { $0 }.count
        return "\(active) on"
    }

    // MARK: - Внутреннее

    private func change(refresh: Bool = true, _ mutate: @escaping (inout UserSettings) -> Void) {
        do {
            try container.settings.update(mutate)
            settings = try container.settings.load()
            errorMessage = nil
            if refresh { Task { await container.refreshNotifications() } }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSources() throws -> [SourceInfo] {
        let manifest = try SeedBundle.load().manifest
        return manifest.sources.map { source in
            let license = manifest.license(id: source.licenseID)
            return SourceInfo(
                id: source.id,
                name: source.name,
                licenseName: license?.name ?? source.licenseID,
                licenseText: license?.text ?? ""
            )
        }
    }
}
