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

            let words = try container.words.allWords()
            let progress = try container.progress.all()
            totalWords = words.filter { $0.origin != .api }.count
            rememberedCount = progress.filter { $0.status == .remembered || $0.status == .known }.count
            dueCount = ReviewScheduler.dueProgress(progress, at: now).count
            nextReviewDate = ReviewScheduler.nextReviewDate(in: progress, after: now)
            newLimit = settings.newWordsPerDay
            newStarted = LearningSession.startedToday(progress: progress, now: now, calendar: calendar)
            cardCount = LearningSession.queue(
                words: words,
                progress: progress,
                dailyWordID: dailyWord?.id,
                newWordsPerDay: settings.newWordsPerDay,
                startedToday: newStarted,
                now: now
            ).count

            let reviewDates = try container.reviews.all().map(\.reviewedAt)
            streak = StreakCalculator.currentStreak(reviewDates: reviewDates, now: now, calendar: calendar)
            week = Self.makeWeek(reviewDates: reviewDates, now: now, calendar: calendar)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func openLearn() {
        container.router.selectedTab = .learn
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
