import Foundation

/// Ключ календарного дня вида `2026-10-08`. Стабильный, сортируемый, пригодный для хранения.
public enum DayKey {
    public static func make(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
