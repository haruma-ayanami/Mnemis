import Foundation
import SwiftData

/// Слово дня, назначенное на конкретную дату (ABOUT.md, раздел 5).
/// Одна запись на один день: `dayKey` в формате `yyyy-MM-dd`.
@Model
public final class DailyWord {
    public var dayKey: String
    public var wordID: UUID
    public var assignedAt: Date

    public init(dayKey: String, wordID: UUID, assignedAt: Date) {
        self.dayKey = dayKey
        self.wordID = wordID
        self.assignedAt = assignedAt
    }
}
