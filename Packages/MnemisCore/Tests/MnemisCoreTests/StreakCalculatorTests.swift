import Testing
import Foundation
@testable import MnemisCore

struct StreakCalculatorTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    @Test func noActivityMeansZero() {
        #expect(StreakCalculator.currentStreak(reviewDates: [], now: now, calendar: calendar) == 0)
    }

    @Test func consecutiveDaysAreCounted() {
        let dates = [daysAgo(0), daysAgo(1), daysAgo(2)]
        #expect(StreakCalculator.currentStreak(reviewDates: dates, now: now, calendar: calendar) == 3)
    }

    @Test func streakSurvivesUntilTodayIsOver() {
        // Сегодня ещё не занимались, вчера и позавчера — да. Серия не прервана.
        let dates = [daysAgo(1), daysAgo(2)]
        #expect(StreakCalculator.currentStreak(reviewDates: dates, now: now, calendar: calendar) == 2)
    }

    @Test func gapBreaksStreak() {
        let dates = [daysAgo(0), daysAgo(2), daysAgo(3)]
        #expect(StreakCalculator.currentStreak(reviewDates: dates, now: now, calendar: calendar) == 1)
    }
}
