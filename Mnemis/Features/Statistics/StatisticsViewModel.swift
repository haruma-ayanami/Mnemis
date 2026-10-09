import Foundation
import Observation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case all = "ALL"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .all: nil
        }
    }
}

/// Одна ячейка тепловой карты: уровень активности 0…4.
struct HeatCell: Identifiable, Equatable {
    let id: Int
    let level: Int
}

/// Сводные числа по прогрессу и истории повторений (ABOUT.md, раздел 15).
@Observable
@MainActor
final class StatisticsViewModel {
    var period: StatsPeriod = .month {
        didSet { recompute() }
    }

    private(set) var learned = 0
    private(set) var reviewCount = 0
    private(set) var accuracyPercent: Int?
    private(set) var currentStreak = 0
    private(set) var longestStreak = 0
    private(set) var heat: [HeatCell] = []
    private(set) var distribution: [(status: LearningStatus, count: Int)] = []
    private(set) var state: ScreenState = .loading

    private var reviews: [ReviewRecord] = []
    private var progress: [WordProgress] = []
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var maxDistribution: Int { max(1, distribution.map(\.count).max() ?? 1) }

    func load() {
        do {
            reviews = try container.reviews.all()
            progress = try container.progress.all()
            state = .loaded
            recompute()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func recompute() {
        let now = container.clock.now
        let calendar = container.clock.calendar
        let start: Date? = period.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: now) }

        let inPeriod = reviews.filter { start == nil || $0.reviewedAt >= start! }
        reviewCount = inPeriod.count
        let correct = inPeriod.filter { $0.rating.isCorrect }.count
        accuracyPercent = inPeriod.isEmpty ? nil : Int((Double(correct) / Double(inPeriod.count) * 100).rounded())
        learned = progress.filter { item in
            guard let introduced = item.introducedAt else { return false }
            return start == nil || introduced >= start!
        }.count

        let dates = reviews.map(\.reviewedAt)
        currentStreak = StreakCalculator.currentStreak(reviewDates: dates, now: now, calendar: calendar)
        longestStreak = StreakCalculator.longestStreak(reviewDates: dates, calendar: calendar)
        heat = Self.makeHeat(reviewDates: dates, now: now, calendar: calendar)

        distribution = [LearningStatus.remembered, .reviewing, .learning, .known].map { status in
            (status, progress.filter { $0.status == status }.count)
        }
    }

    /// 12 недель × 7 дней, по колонкам (неделя за неделей). Последняя ячейка — сегодня.
    static func makeHeat(reviewDates: [Date], now: Date, calendar: Calendar) -> [HeatCell] {
        var calendar = calendar
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let first = calendar.date(byAdding: .day, value: -11 * 7, to: weekStart) else { return [] }

        var counts: [Date: Int] = [:]
        for date in reviewDates { counts[calendar.startOfDay(for: date), default: 0] += 1 }
        let maxCount = max(1, counts.values.max() ?? 1)

        return (0..<(12 * 7)).map { index in
            let week = index / 7, weekday = index % 7
            let day = calendar.date(byAdding: .day, value: week * 7 + weekday, to: first) ?? first
            let count = day > today ? 0 : counts[day] ?? 0
            let level = count == 0 ? 0 : min(4, 1 + Int(Double(count) / Double(maxCount) * 3.0))
            return HeatCell(id: index, level: level)
        }
    }
}
