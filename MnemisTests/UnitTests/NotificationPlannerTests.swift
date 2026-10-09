import Testing
import Foundation
@testable import Mnemis

struct NotificationPlannerTests {
    private func settings(_ change: (inout UserSettings) -> Void = { _ in }) -> UserSettings {
        var settings = UserSettings()
        settings.dailyReminderEnabled = true
        settings.maxNotificationsPerDay = 3
        change(&settings)
        return settings
    }

    @Test func nothingIsPlannedWhenMasterSwitchIsOff() {
        var off = settings()
        off.dailyReminderEnabled = false
        #expect(NotificationPlanner.plan(for: off).isEmpty)
    }

    @Test func plansEveryTypeOnEverySelectedDay() {
        let plan = NotificationPlanner.plan(for: settings())
        #expect(plan.count == 7 * 3)
        #expect(Set(plan.map(\.kind)) == Set(NotificationKind.allCases))
    }

    @Test func respectsSelectedWeekdays() {
        // Только понедельник и воскресенье: биты 0 и 6.
        let plan = NotificationPlanner.plan(for: settings { $0.notificationWeekdays = 0b1000001 })
        #expect(Set(plan.map(\.weekday)) == [2, 1])
    }

    @Test func maximumPerDayKeepsHigherPriorityTypes() {
        let plan = NotificationPlanner.plan(for: settings { $0.maxNotificationsPerDay = 2 })
        #expect(Set(plan.map(\.kind)) == [.wordOfDay, .reviews])
    }

    @Test func disabledTypesAreSkipped() {
        let plan = NotificationPlanner.plan(for: settings { $0.notifyReviews = false; $0.notifyStreak = false })
        #expect(Set(plan.map(\.kind)) == [.wordOfDay])
    }

    @Test func nothingIsScheduledDuringQuietHours() {
        let night = settings { $0.dailyReminderMinutes = 3 * 60 }
        let late = settings { $0.dailyReminderMinutes = 23 * 60 }
        for plan in [NotificationPlanner.plan(for: night), NotificationPlanner.plan(for: late)] {
            for item in plan {
                let minutes = item.hour * 60 + item.minute
                #expect(minutes >= NotificationPlanner.quietEndMinutes)
                #expect(minutes < NotificationPlanner.quietStartMinutes)
            }
        }
    }

    @MainActor
    @Test func settingsSurviveRoundTripThroughStorage() throws {
        let container = try AppContainer.inMemory(clock: TestClock())
        try container.settings.update {
            $0.notifyStreak = false
            $0.notificationWeekdays = 0b0011111
            $0.maxNotificationsPerDay = 1
        }
        let loaded = try container.settings.load()
        #expect(!loaded.notifyStreak)
        #expect(loaded.notificationWeekdays == 0b0011111)
        #expect(loaded.maxNotificationsPerDay == 1)
    }
}
