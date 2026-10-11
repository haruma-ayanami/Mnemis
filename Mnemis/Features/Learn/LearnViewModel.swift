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

    /// День, на который собрана очередь: при смене дня сессия собирается заново.
    private var queueDayID: String?
    /// Слова, оценённые в этой сессии: повторно в очередь их не подмешиваем.
    private var ratedIDs: Set<UUID> = []
    private var progressByWord: [UUID: WordProgress] = [:]
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var current: Word? { queue.first }
    var reviewedCount: Int { results.count }
    var correctCount: Int { results.filter(\.isCorrect).count }
    var isSessionFinished: Bool { reviewedCount > 0 && queue.isEmpty }
    /// Повторение — слово, которое уже оценивали. Не начатое и отправленное в колоду вручную слово считается новым.
    private static func isReview(_ progress: WordProgress) -> Bool {
        progress.correctCount + progress.incorrectCount > 0 || progress.repetitionCount > 0
    }

    /// Сколько повторений осталось в очереди.
    var remainingReviewCount: Int { queue.filter { progressByWord[$0.id].map(Self.isReview) ?? false }.count }
    var remainingNewCount: Int { queue.count - remainingReviewCount }

    var accuracyPercent: Int {
        results.isEmpty ? 0 : Int((Double(correctCount) / Double(results.count) * 100).rounded())
    }

    var durationText: String {
        guard let startedAt, let finishedAt else { return "0:00" }
        let seconds = max(0, Int(finishedAt.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Собирает сессию на текущий день. В пределах дня возврат на вкладку не сбрасывает прогресс сессии,
    /// но слова в очереди перечитываются: правка перевода в Words сразу видна в сессии.
    /// Когда день сменился, сессия собирается заново: вчерашняя очередь и результаты не переносятся.
    func startIfNeeded() {
        guard queueDayID == todayID else {
            start()
            return
        }
        refreshQueuedWords()
        appendNewlyDue()
    }

    /// Слова, отправленные в колоду вручную (карточка слова), попадают в идущую сессию без сброса результатов.
    private func appendNewlyDue() {
        guard let due = try? container.progress.due(at: container.clock.now) else { return }
        let queued = Set(queue.map(\.id))
        let fresh = due.filter { !queued.contains($0.wordID) && !ratedIDs.contains($0.wordID) }
        guard !fresh.isEmpty,
              let words = try? container.words.words(ids: fresh.map(\.wordID)) else { return }
        let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let added = fresh.compactMap { byID[$0.wordID] }
        guard !added.isEmpty else { return }
        for item in fresh { progressByWord[item.wordID] = item }
        queue.append(contentsOf: added)
        totalCount += added.count
        let addedReviews = fresh.filter(Self.isReview).count
        reviewCount += addedReviews
        newCount += added.count - addedReviews
        finishedAt = nil
        loadCurrentDetails()
    }

    /// Обновляет слова очереди из базы, сохраняя порядок. Удалённые слова выпадают из очереди.
    func refreshQueuedWords() {
        guard !queue.isEmpty, let fresh = try? container.words.words(ids: queue.map(\.id)) else { return }
        let byID = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let updated = queue.compactMap { byID[$0.id] }
        guard updated != queue else { return }
        queue = updated
        loadCurrentDetails()
    }

    func restart() {
        start(extraNewWords: 3)
    }

    func rate(_ rating: ReviewRating) {
        guard let word = current else { return }
        do {
            try container.submitReview.execute(wordID: word.id, rating: rating, sessionID: sessionID)
            queue.removeFirst()
            results.append(rating)
            ratedIDs.insert(word.id)
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

    /// Идентификатор текущего дня: по нему видно, что очередь собрана на вчера.
    private var todayID: String {
        LocalDay.id(for: container.clock.now, calendar: container.clock.calendar)
    }

    private func start(extraNewWords: Int = 0) {
        sessionID = UUID()
        results = []
        ratedIDs = []
        finishedAt = nil
        queueDayID = todayID
        do {
            let settings = try container.settings.load()
            let calendar = container.clock.calendar
            let now = container.clock.now

            let dayID = LocalDay.id(for: now, calendar: calendar)
            let dailyWordID = try container.dailyWords.assignment(forDay: dayID)?.wordID

            let snapshot = try container.studyQueue.snapshot(
                newWordsPerDay: settings.newWordsPerDay + extraNewWords,
                dailyWordID: dailyWordID,
                now: now
            )
            // В снимке — только повторения, которые сейчас пора сделать.
            let dueProgress = snapshot.progress
            progressByWord = Dictionary(dueProgress.map { ($0.wordID, $0) }, uniquingKeysWith: { first, _ in first })
            queue = snapshot.queue
            totalCount = queue.count
            let reviewIDs = Set(dueProgress.filter(Self.isReview).map(\.wordID))
            reviewCount = queue.filter { reviewIDs.contains($0.id) }.count
            newCount = queue.count - reviewCount
            nextReviewDate = try container.progress.nextReviewDate(after: now)
            dueSoonCount = try container.progress.countScheduled(after: now, before: now.addingTimeInterval(86_400))
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
