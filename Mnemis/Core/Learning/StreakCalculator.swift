import Foundation

/// Streak считается по календарным дням, а не по блокам в 24 часа (ARCHITECTURE.md, раздел 9).
enum StreakCalculator {
    /// Если сегодня ещё не занимались, серия считается от вчера: она не обрывается до конца дня.
    static func currentStreak(reviewDates: [Date], now: Date, calendar: Calendar) -> Int {
        let activeDays = Set(reviewDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)

        if !activeDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Самая длинная серия за всё время.
    static func longestStreak(reviewDates: [Date], calendar: Calendar) -> Int {
        let days = Set(reviewDates.map { calendar.startOfDay(for: $0) }).sorted()
        var longest = 0
        var run = 0
        var previous: Date?

        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = day
        }
        return longest
    }
}
