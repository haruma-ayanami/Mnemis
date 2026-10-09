import Foundation

/// Источник времени и календаря. Весь код берёт «сейчас» отсюда, а не из `Date()`,
/// чтобы тесты были детерминированными (ARCHITECTURE.md, раздел 9).
protocol Clock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemClock: Clock {
    var now: Date { .now }
    var calendar: Calendar { .current }
}
