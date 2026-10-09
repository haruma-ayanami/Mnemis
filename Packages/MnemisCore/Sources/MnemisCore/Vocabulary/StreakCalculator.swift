import Foundation

/// Streak: сколько дней подряд была хотя бы одна учебная активность (ABOUT.md, раздел 16).
public enum StreakCalculator {
    /// Если сегодня ещё не занимались, streak считается от вчера: день не прерывается, пока он не закончился.
    public static func currentStreak(reviewDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
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
}
