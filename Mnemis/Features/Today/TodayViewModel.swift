import Foundation
import Observation

enum WeekDayState: Equatable {
    case done
    case today
    case missed
    case upcoming
}

struct WeekDay: Identifiable, Equatable {
    let id: Int
    let letter: String
    let state: WeekDayState
}

@Observable
@MainActor
final class TodayViewModel {
    private(set) var dailyWord: Word?
    private(set) var dailyExample: String?
    /// Идиома дня из словаря; nil, если идиом нет или их показ выключен в Settings.
    private(set) var idiom: Word?
    private(set) var idiomExample: String?
    private(set) var dueCount = 0
    private(set) var newStarted = 0
    private(set) var newLimit = 5
    private(set) var cardCount = 0
    private(set) var streak = 0
    private(set) var totalWords = 0
    private(set) var rememberedCount = 0
    private(set) var week: [WeekDay] = []
    private(set) var nextReviewDate: Date?
    private(set) var state: ScreenState = .loading

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    /// Примерная длительность сессии: ~20 секунд на карточку.
    var estimatedMinutes: Int { max(1, Int((Double(cardCount) * 0.33).rounded())) }

    func load() {
        do {
            let settings = try container.settings.load()
            let now = container.clock.now
            let calendar = container.clock.calendar

            dailyWord = try container.dailyWordUseCase.todaysWord(preferredLevel: settings.proficiencyLevel.rawValue)

            dailyExample = try dailyWord.flatMap { try container.words.examples(forWordID: $0.id).first?.sentence }
            idiom = settings.phrasesInToday
                ? try container.dailyWordUseCase.idiomOfTheDay(dayID: LocalDay.id(for: now, calendar: calendar))
                : nil
            idiomExample = try idiom.flatMap { try container.words.examples(forWordID: $0.id).first?.sentence }

            // Все числа здесь — счётчики и одна дата из базы: прогресс целиком не читаем.
            totalWords = try container.words.countOwnAndBuiltIn()
            rememberedCount = try container.progress.countMastered()
            dueCount = try container.progress.countDue(at: now)
            nextReviewDate = try container.progress.nextReviewDate(after: now)
            newLimit = settings.newWordsPerDay
            newStarted = try container.progress.countIntroduced(since: LocalDay.start(of: now, calendar: calendar))
            cardCount = try container.studyQueue.cardCount(newWordsPerDay: settings.newWordsPerDay, now: now)

            // Серия и неделя считаются по сводке за дни, а не по всей истории.
            let activeDays = try container.dailyActivity.all().map(\.dayStart)
            streak = StreakCalculator.currentStreak(reviewDates: activeDays, now: now, calendar: calendar)
            week = Self.makeWeek(reviewDates: activeDays, now: now, calendar: calendar)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func openLearn() {
        container.router.startSession()
    }

    /// Неделя с понедельника: сделано, сегодня, пропущено, впереди.
    static func makeWeek(reviewDates: [Date], now: Date, calendar: Calendar) -> [WeekDay] {
        var calendar = calendar
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let active = Set(reviewDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        let letters = ["M", "T", "W", "T", "F", "S", "S"]

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let state: WeekDayState
            if active.contains(day) && day != today {
                state = .done
            } else if day == today {
                state = active.contains(day) ? .done : .today
            } else if day < today {
                state = .missed
            } else {
                state = .upcoming
            }
            return WeekDay(id: offset, letter: letters[offset], state: state)
        }
    }
}
