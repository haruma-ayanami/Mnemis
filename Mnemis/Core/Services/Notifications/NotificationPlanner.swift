import Foundation

enum NotificationKind: String, CaseIterable, Sendable {
    case wordOfDay
    case reviews
    case streak
}

/// Одно запланированное уведомление: повторяется каждую неделю в указанный день и время.
struct PlannedNotification: Equatable, Sendable {
    let kind: NotificationKind
    /// День недели по `Calendar`: 1 — воскресенье, 2 — понедельник.
    let weekday: Int
    let hour: Int
    let minute: Int

    var identifier: String { "mnemis.\(kind.rawValue).\(weekday)" }
}

/// Чистый расчёт расписания уведомлений по настройкам (ABOUT.md, раздел 17).
/// Правила: уведомления только в выбранные дни, не ночью, не больше лимита в день.
enum NotificationPlanner {
    /// Тихие часы: с 22:00 до 08:00 ничего не отправляется.
    static let quietStartMinutes = 22 * 60
    static let quietEndMinutes = 8 * 60

    static let reviewsMinutes = 14 * 60 + 30
    static let streakMinutes = 20 * 60

    static func plan(for settings: UserSettings) -> [PlannedNotification] {
        guard settings.dailyReminderEnabled else { return [] }

        // Приоритет при ограничении лимитом: слово дня, повторения, серия.
        var kinds: [(NotificationKind, Int)] = []
        if settings.notifyWordOfDay { kinds.append((.wordOfDay, settings.dailyReminderMinutes)) }
        if settings.notifyReviews { kinds.append((.reviews, reviewsMinutes)) }
        if settings.notifyStreak { kinds.append((.streak, streakMinutes)) }
        kinds = Array(kinds.prefix(max(0, settings.maxNotificationsPerDay)))

        var result: [PlannedNotification] = []
        for bit in 0..<7 where settings.notificationWeekdays & (1 << bit) != 0 {
            let weekday = bit == 6 ? 1 : bit + 2
            for (kind, minutes) in kinds {
                let clamped = clampToDaytime(minutes)
                result.append(PlannedNotification(kind: kind, weekday: weekday, hour: clamped / 60, minute: clamped % 60))
            }
        }
        return result
    }

    /// Переносит время из тихих часов на ближайшую границу дня.
    static func clampToDaytime(_ minutes: Int) -> Int {
        min(max(minutes, quietEndMinutes), quietStartMinutes - 1)
    }
}
