import Foundation
import UserNotifications
import OSLog

/// Локальные уведомления. Не требует аккаунта и сети.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let categoryID = "mnemis.word"
    static let learnActionID = "mnemis.learn"
    static let snoozeActionID = "mnemis.snooze"

    private let center = UNUserNotificationCenter.current()
    /// Вызывается, когда пользователь нажал на уведомление или «Learn now».
    var onOpenLearn: (() -> Void)?

    override init() {
        super.init()
        center.delegate = self
        let learn = UNNotificationAction(identifier: Self.learnActionID, title: String(localized: "Learn now"), options: [.foreground])
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID, title: String(localized: "Remind me in 1 hour"), options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryID, actions: [learn, snooze], intentIdentifiers: [])
        ])
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Показывает системный запрос разрешения. Возвращает, разрешил ли пользователь.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Пересоздаёт расписание по настройкам. Вызывается при каждом изменении настроек.
    func apply(settings: UserSettings) async {
        center.removeAllPendingNotificationRequests()
        guard await isAuthorized() else { return }

        for item in NotificationPlanner.plan(for: settings) {
            var date = DateComponents()
            date.weekday = item.weekday
            date.hour = item.hour
            date.minute = item.minute

            let content = UNMutableNotificationContent()
            content.categoryIdentifier = Self.categoryID
            content.sound = settings.soundEnabled ? .default : nil
            switch item.kind {
            case .wordOfDay:
                content.title = String(localized: "Your word of the day")
                content.body = String(localized: "Guess the meaning, then check it.")
            case .reviews:
                content.title = String(localized: "Words are ready to review")
                content.body = String(localized: "A few minutes now keeps them fresh.")
            case .streak:
                content.title = String(localized: "Keep your streak")
                content.body = String(localized: "One short session before midnight is enough.")
            }

            let request = UNNotificationRequest(
                identifier: item.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            )
            do {
                try await center.add(request)
            } catch {
                Log.learning.error("Notification scheduling failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        if action == Self.snoozeActionID {
            let content = response.notification.request.content.mutableCopy() as? UNMutableNotificationContent
            guard let content else { return }
            let request = UNNotificationRequest(
                identifier: "mnemis.snooze",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
            )
            try? await center.add(request)
        } else {
            await MainActor.run { self.onOpenLearn?() }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
