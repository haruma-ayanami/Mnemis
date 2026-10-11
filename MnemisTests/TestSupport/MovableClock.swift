import Foundation
@testable import Mnemis

/// Часы, которые можно перевести на другой день: проверяем переход через полночь.
/// Календарь в UTC, как у `TestClock`, чтобы тесты не зависели от часового пояса машины.
final class MovableClock: Clock, @unchecked Sendable {
    var now: Date
    let calendar: Calendar

    init(now: Date) {
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
    }
}
