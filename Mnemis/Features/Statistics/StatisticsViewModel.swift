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
        didSet {
            do {
                try recompute()
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private(set) var learned = 0
    private(set) var reviewCount = 0
    private(set) var accuracyPercent: Int?
    private(set) var currentStreak = 0
    private(set) var longestStreak = 0
    private(set) var heat: [HeatCell] = []
    private(set) var distribution: [(status: LearningStatus, count: Int)] = []
    /// Текущий уровень CEFR и процент освоенных слов на нём.
    private(set) var cefrLevel: LanguageLevel = .b1
    private(set) var cefrPercent = 0
    private(set) var state: ScreenState = .loading

    private var activity: [DailyActivity] = []
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var maxDistribution: Int { max(1, distribution.map(\.count).max() ?? 1) }

    func load() {
        do {
            activity = try container.dailyActivity.all()
            try recompute()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func recompute() throws {
        let now = container.clock.now
        let calendar = container.clock.calendar
        let start: Date? = period.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: now) }

        // Периоды считаем по дням: сводка хранит только начало дня.
        let startDay = start.map { calendar.startOfDay(for: $0) }
        let inPeriod = activity.filter { startDay == nil || $0.dayStart >= startDay! }
        reviewCount = inPeriod.reduce(0) { $0 + $1.reviewCount }
        let correct = inPeriod.reduce(0) { $0 + $1.correctCount }
        accuracyPercent = reviewCount == 0 ? nil : Int((Double(correct) / Double(reviewCount) * 100).rounded())
        learned = try container.progress.countIntroduced(since: start)

        let activeDays = activity.map(\.dayStart)
        currentStreak = StreakCalculator.currentStreak(reviewDates: activeDays, now: now, calendar: calendar)
        longestStreak = StreakCalculator.longestStreak(reviewDates: activeDays, calendar: calendar)
        heat = Self.makeHeat(activity: activity, now: now, calendar: calendar)

        distribution = try [LearningStatus.remembered, .reviewing, .learning, .known].map { status in
            (status, try container.progress.count(status: status))
        }

        // Прогресс к следующему уровню CEFR: какая доля слов текущего уровня уже освоена.
        cefrLevel = try container.settings.load().proficiencyLevel
        let levelWords = try container.words.countWords(level: cefrLevel.rawValue)
        let masteredIDs = try container.progress.masteredWordIDs()
        let masteredOnLevel = try container.words.countWords(level: cefrLevel.rawValue, ids: masteredIDs)
        cefrPercent = levelWords == 0 ? 0 : Int((Double(masteredOnLevel) / Double(levelWords) * 100).rounded())
    }

    /// 12 недель × 7 дней, по колонкам (неделя за неделей). Последняя ячейка — сегодня.
    static func makeHeat(activity: [DailyActivity], now: Date, calendar: Calendar) -> [HeatCell] {
        var calendar = calendar
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let first = calendar.date(byAdding: .day, value: -11 * 7, to: weekStart) else { return [] }

        var counts: [Date: Int] = [:]
        for day in activity { counts[calendar.startOfDay(for: day.dayStart), default: 0] += day.reviewCount }
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
