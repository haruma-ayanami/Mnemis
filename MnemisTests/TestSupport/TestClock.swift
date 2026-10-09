import Foundation
@testable import Mnemis

/// Фиксированное время и календарь в UTC: тесты не зависят от часового пояса машины.
struct TestClock: Clock {
    var now: Date
    var calendar: Calendar

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        self.calendar = calendar
    }

    func advanced(by seconds: TimeInterval) -> TestClock {
        TestClock(now: now.addingTimeInterval(seconds))
    }
}
