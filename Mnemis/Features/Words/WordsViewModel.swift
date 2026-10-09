import Foundation
import Observation

/// Личный словарь: список страницами, поиск по базе, статусы и добавление слов.
/// В памяти держим только текущую страницу, статусы и счётчики: весь словарь здесь не читается.
@Observable
@MainActor
final class WordsViewModel {
    /// Размер страницы списка и предел результатов поиска.
    static let pageSize = 120
    static let searchLimit = 200

    var query = "" {
        didSet {
            searchTask?.cancel()
            guard !query.isEmpty else {
                reloadList()
                return
            }
            // Короткая пауза: не ищем на каждый введённый символ.
            searchTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self?.reloadList()
            }
        }
    }

    /// `nil` — все слова.
    var filter: LearningStatus? { didSet { reloadList() } }

    /// Строки, которые показывает список: страница, результаты поиска или слова статуса.
    private(set) var results: [Word] = []
    private(set) var totalCount = 0
    private(set) var statuses: [UUID: LearningStatus] = [:]
    private(set) var state: ScreenState = .loading

    private var counts: [LearningStatus?: Int] = [:]
    private var hasMorePages = false
    /// Слова выбранного статуса, кроме «new». Их немного, поэтому держим список целиком и режем страницами.
    private var statusWords: [Word] = []
    private var searchTask: Task<Void, Never>?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    /// Количество слов для чипа фильтра.
    func count(for filter: LearningStatus?) -> Int {
        counts[filter] ?? 0
    }

    func status(of word: Word) -> LearningStatus {
        statuses[word.id] ?? .new
    }

    func load() {
        do {
            totalCount = try container.words.countAll()
            try recount()
            reloadList()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Подгружаем следующую страницу, когда список докрутился до последней строки.
    func loadMoreIfNeeded(after word: Word) {
        guard hasMorePages, query.isEmpty, word.id == results.last?.id else { return }
        do {
            let appended: [Word]
            if let filter, filter != .new {
                let upper = min(statusWords.count, results.count + Self.pageSize)
                guard results.count < upper else {
                    hasMorePages = false
                    return
                }
                appended = Array(statusWords[results.count..<upper])
                hasMorePages = upper < statusWords.count
            } else {
                appended = try container.words.page(
                    offset: results.count,
                    limit: Self.pageSize,
                    onlyNotStarted: filter == .new
                )
                hasMorePages = appended.count == Self.pageSize
            }
            results += appended
            try refreshStatuses(for: appended, merging: true)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Свайп «I know»: слово выходит из повторений, как в карточке.
    func markKnown(_ word: Word) {
        perform { try container.wordStatus.markKnown(wordID: word.id) }
    }

    /// Свайп «Suspend»: слово временно выходит из очереди.
    func suspend(_ word: Word) {
        perform { try container.wordStatus.suspend(wordID: word.id) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Добавляет слово и в фоне пытается дополнить его из источников. Без сети слово всё равно сохраняется.
    @discardableResult
    func addWord(lemma: String, translation: String) throws -> Word {
        let word = try container.wordEditor.addWord(lemma: lemma, translation: translation)
        load()
        let enrichment = container.wordEnrichment
        Task { [weak self] in
            _ = try? await enrichment.enrich(wordID: word.id)
            self?.load()
        }
        return word
    }

    // MARK: - Внутреннее

    /// Счётчики чипов считает база: по статусам прогресса и числу слов без прогресса.
    private func recount() throws {
        var result: [LearningStatus?: Int] = [nil: totalCount]
        for status in LearningStatus.allCases where status != .new {
            result[status] = try container.progress.count(status: status)
        }
        result[.new] = try container.words.countNotStarted()
        counts = result
    }

    /// Статусы нужны только для строк, которые видны. Словарь целиком не перебираем.
    private func refreshStatuses(for shown: [Word], merging: Bool = false) throws {
        let fresh = try container.progress.statuses(forWordIDs: shown.map(\.id))
        if merging {
            statuses.merge(fresh) { _, new in new }
        } else {
            statuses = fresh
        }
    }

    /// Пересобирает список под текущие запрос и фильтр. Всё, что читается, — это первая страница.
    private func reloadList() {
        do {
            results = []
            hasMorePages = false
            statusWords = []

            if !query.isEmpty {
                let found = try container.words.search(query, limit: Self.searchLimit)
                // Статусы нужны до фильтра: по ним отбираем результаты.
                try refreshStatuses(for: found)
                results = filter.map { selected in found.filter { status(of: $0) == selected } } ?? found
            } else if let filter, filter != .new {
                statusWords = try wordsWithStatus(filter)
                results = Array(statusWords.prefix(Self.pageSize))
                hasMorePages = statusWords.count > results.count
            } else {
                results = try container.words.page(
                    offset: 0,
                    limit: Self.pageSize,
                    onlyNotStarted: filter == .new
                )
                hasMorePages = results.count == Self.pageSize
            }
            try refreshStatuses(for: results)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func wordsWithStatus(_ status: LearningStatus) throws -> [Word] {
        let ids = try container.progress.wordIDs(status: status)
        return try container.words.words(ids: ids).sorted { $0.normalizedLemma < $1.normalizedLemma }
    }
}
