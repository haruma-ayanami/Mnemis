import Foundation

/// Учебная очередь без чтения всего словаря и прогресса: из базы берём повторения, Daily Word и только нужные новые слова.
/// Состав и порядок задаёт `LearningSession`; здесь решаем, какие строки вообще читать.
@MainActor
struct StudyQueueUseCase {
    struct Snapshot {
        let queue: [Word]
        /// Повторения, которые сейчас пора сделать: ими же пользуется экран обучения.
        let progress: [WordProgress]
        let startedToday: Int
    }

    let words: WordRepository
    let progress: ProgressRepository
    let clock: any Clock

    /// Сколько карточек будет в сессии. Считаем счётчиками, без чтения слов и прогресса.
    func cardCount(newWordsPerDay: Int, now: Date) throws -> Int {
        let due = try progress.countDue(at: now)
        let started = try progress.countIntroduced(since: dayStart(for: now))
        let remaining = max(0, newWordsPerDay - started)
        let fresh = try words.countFreshCandidates()
        return due + min(remaining, fresh)
    }

    func snapshot(newWordsPerDay: Int, dailyWordID: UUID?, now: Date) throws -> Snapshot {
        let due = try progress.due(at: now)
        let started = try progress.countIntroduced(since: dayStart(for: now))
        let remaining = max(0, newWordsPerDay - started)

        // Daily Word добавляем только если его ещё не начинали: начатое в очередь новых слов не попадает.
        var ids = due.map(\.wordID)
        if let dailyWordID, try progress.progress(forWordID: dailyWordID) == nil {
            ids.append(dailyWordID)
        }

        // Новых слов нужно не больше `remaining`; +1 запас на случай, когда Daily Word попал в выборку.
        let candidates = try words.words(ids: ids) + words.freshCandidates(limit: remaining + 1)
        let unique = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let queue = LearningSession.queue(
            words: Array(unique.values),
            progress: due,
            dailyWordID: dailyWordID,
            newWordsPerDay: newWordsPerDay,
            startedToday: started,
            now: now
        )
        return Snapshot(queue: queue, progress: due, startedToday: started)
    }

    private func dayStart(for date: Date) -> Date {
        LocalDay.start(of: date, calendar: clock.calendar)
    }
}
