import Foundation

/// Сводка за один локальный день: сколько оценок и сколько из них верных.
/// Серия, неделя, тепловая карта и точность считаются по ней, без чтения всей истории повторений.
struct DailyActivity: Equatable, Sendable {
    let localDayID: String
    let dayStart: Date
    var reviewCount: Int
    var correctCount: Int
}
