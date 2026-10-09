import Foundation

/// Идентификатор локального дня (`2026-10-08`) для привязки Daily Word.
enum LocalDay {
    static func id(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func start(of date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }
}
