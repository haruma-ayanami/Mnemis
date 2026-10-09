import Foundation

/// Слово дня, закреплённое за локальным днём. Выбирается один раз и не меняется до конца дня
/// (ARCHITECTURE.md, раздел 6).
struct DailyWordAssignment: Identifiable, Equatable, Sendable {
    let id: UUID
    /// Локальный день в формате `yyyy-MM-dd`.
    var localDayID: String
    var wordID: UUID
    var assignedAt: Date
    var timeZoneIdentifier: String

    init(
        id: UUID = UUID(),
        localDayID: String,
        wordID: UUID,
        assignedAt: Date,
        timeZoneIdentifier: String
    ) {
        self.id = id
        self.localDayID = localDayID
        self.wordID = wordID
        self.assignedAt = assignedAt
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}
