import Testing
import Foundation
@testable import Mnemis

struct StreakCalculatorTests {
    let clock = TestClock()

    private func daysAgo(_ days: Int) -> Date {
        clock.calendar.date(byAdding: .day, value: -days, to: clock.now)!
    }

    @Test func noActivityMeansZero() {
        #expect(StreakCalculator.currentStreak(reviewDates: [], now: clock.now, calendar: clock.calendar) == 0)
    }

    @Test func consecutiveDaysAreCounted() {
        let dates = [daysAgo(0), daysAgo(1), daysAgo(2)]
        #expect(StreakCalculator.currentStreak(reviewDates: dates, now: clock.now, calendar: clock.calendar) == 3)
    }

    @Test func streakSurvivesUntilTodayIsOver() {
        // Сегодня ещё не занимались, вчера и позавчера — да. Серия не прервана.
        let dates = [daysAgo(1), daysAgo(2)]
        #expect(StreakCalculator.currentStreak(reviewDates: dates, now: clock.now, calendar: clock.calendar) == 2)
    }

    @Test func gapBreaksStreak() {
        let dates = [daysAgo(0), daysAgo(2), daysAgo(3)]
        #expect(StreakCalculator.currentStreak(reviewDates: dates, now: clock.now, calendar: clock.calendar) == 1)
    }

    @Test func longestStreakIsFoundAcrossHistory() {
        let dates = [daysAgo(0), daysAgo(10), daysAgo(11), daysAgo(12), daysAgo(13)]
        #expect(StreakCalculator.longestStreak(reviewDates: dates, calendar: clock.calendar) == 4)
    }
}
