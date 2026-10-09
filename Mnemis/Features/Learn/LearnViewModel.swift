import Foundation
import Observation

/// Учебная сессия: очередь из повторений и новых слов, оценки и итоги.
@Observable
@MainActor
final class LearnViewModel {
    private(set) var queue: [Word] = []
    private(set) var state: ScreenState = .loading
    private(set) var results: [ReviewRating] = []
    private(set) var totalCount = 0
    private(set) var newCount = 0
    private(set) var reviewCount = 0
    private(set) var nextReviewDate: Date?
    private(set) var dueSoonCount = 0
    private(set) var sessionID = UUID()
    private(set) var currentExamples: [ExampleSentence] = []
    private(set) var currentStatus: LearningStatus = .new
    private(set) var startedAt: Date?
    private(set) var finishedAt: Date?

    private var hasStarted = false
    private var progressByWord: [UUID: WordProgress] = [:]
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var current: Word? { queue.first }
    var reviewedCount: Int { results.count }
    var correctCount: Int { results.filter(\.isCorrect).count }
    var isSessionFinished: Bool { reviewedCount > 0 && queue.isEmpty }

    var accuracyPercent: Int {
        results.isEmpty ? 0 : Int((Double(correctCount) / Double(results.count) * 100).rounded())
    }

    var durationText: String {
        guard let startedAt, let finishedAt else { return "0:00" }
        let seconds = max(0, Int(finishedAt.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Запускает сессию один раз. Возврат на вкладку не сбрасывает прогресс сессии.
    func startIfNeeded() {
        guard !hasStarted else { return }
        start()
    }

    func restart() {
        sessionID = UUID()
        results = []
        finishedAt = nil
        start(extraNewWords: 3)
    }

    func rate(_ rating: ReviewRating) {
        guard let word = current else { return }
        do {
            try container.submitReview.execute(wordID: word.id, rating: rating, sessionID: sessionID)
            queue.removeFirst()
            results.append(rating)
            if queue.isEmpty { finishedAt = container.clock.now }
            loadCurrentDetails()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// «Я уже знаю это слово»: слово выходит из повторений, как при `markKnown`.
    func markCurrentKnown() {
        guard let word = current else { return }
        do {
            try container.wordStatus.markKnown(wordID: word.id)
            queue.removeFirst()
            if queue.isEmpty && !results.isEmpty { finishedAt = container.clock.now }
            loadCurrentDetails()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Подпись интервала под кнопкой оценки: `<10m`, `2d`, `3w`.
    func intervalLabel(for rating: ReviewRating) -> String {
        guard let word = current else { return "" }
        let now = container.clock.now
        let existing = progressByWord[word.id] ?? WordProgress(wordID: word.id, createdAt: now)
        let next = container.engine.schedule(existing, rating: rating, now: now)
        return Self.format(days: next.intervalDays)
    }

    static func format(days: Double) -> String {
        let minutes = days * 1440
        if minutes < 60 { return "<\(Int(max(10, (minutes / 5).rounded(.up) * 5)))m" }
        if days < 1 { return "\(Int((days * 24).rounded()))h" }
        if days < 14 { return "\(Int(days.rounded()))d" }
        if days < 60 { return "\(Int((days / 7).rounded()))w" }
        return "\(Int((days / 30).rounded()))mo"
    }

    private func start(extraNewWords: Int = 0) {
        hasStarted = true
        do {
            let settings = try container.settings.load()
            let calendar = container.clock.calendar
            let now = container.clock.now

            let words = try container.words.allWords()
            let progress = try container.progress.all()
            progressByWord = Dictionary(progress.map { ($0.wordID, $0) }, uniquingKeysWith: { first, _ in first })
            let dayID = LocalDay.id(for: now, calendar: calendar)
            let dailyWordID = try container.dailyWords.assignment(forDay: dayID)?.wordID
            let startedToday = LearningSession.startedToday(progress: progress, now: now, calendar: calendar)

            queue = LearningSession.queue(
                words: words,
                progress: progress,
                dailyWordID: dailyWordID,
                newWordsPerDay: settings.newWordsPerDay + extraNewWords,
                startedToday: startedToday,
                now: now
            )
            totalCount = queue.count
            let dueIDs = Set(ReviewScheduler.dueProgress(progress, at: now).map(\.wordID))
            reviewCount = queue.filter { dueIDs.contains($0.id) }.count
            newCount = queue.count - reviewCount
            nextReviewDate = ReviewScheduler.nextReviewDate(in: progress, after: now)
            dueSoonCount = progress.filter { ($0.nextReviewAt ?? .distantFuture) > now && ($0.nextReviewAt ?? .distantFuture) < now.addingTimeInterval(86_400) }.count
            startedAt = now
            loadCurrentDetails()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func loadCurrentDetails() {
        guard let word = current else {
            currentExamples = []
            return
        }
        currentExamples = (try? container.words.examples(forWordID: word.id)) ?? []
        currentStatus = progressByWord[word.id]?.status ?? .new
    }
}
