import Foundation
import Observation

/// Личный словарь: список, статусы, поиск и добавление слов.
@Observable
@MainActor
final class WordsViewModel {
    var query = "" { didSet { refilter() } }
    /// `nil` — все слова.
    var filter: LearningStatus? { didSet { refilter() } }
    private(set) var words: [Word] = []
    private(set) var statuses: [UUID: LearningStatus] = [:]
    private(set) var userExamples: [UUID: [String]] = [:]
    private(set) var state: ScreenState = .loading

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    /// Результаты поиска и фильтра. Считаются один раз при изменении, а не при каждой отрисовке.
    private(set) var results: [Word] = []
    private var counts: [LearningStatus?: Int] = [:]

    /// Количество слов для чипа фильтра.
    func count(for filter: LearningStatus?) -> Int {
        counts[filter] ?? 0
    }

    private func refilter() {
        let found = SearchService.search(query, in: words, userTexts: userExamples)
        results = filter.map { selected in found.filter { status(of: $0) == selected } } ?? found
    }

    private func recount() {
        var result: [LearningStatus?: Int] = [nil: words.count]
        for word in words { result[status(of: word), default: 0] += 1 }
        counts = result
    }

    func status(of word: Word) -> LearningStatus {
        statuses[word.id] ?? .new
    }

    func load() {
        do {
            words = try container.words.allWords().sorted { $0.lemma.localizedCaseInsensitiveCompare($1.lemma) == .orderedAscending }
            statuses = Dictionary(
                try container.progress.all().map { ($0.wordID, $0.status) },
                uniquingKeysWith: { first, _ in first }
            )
            let examples = try container.words.allExamples().filter(\.isUserCreated)
            userExamples = Dictionary(grouping: examples, by: \.wordID).mapValues { $0.map(\.sentence) }
            recount()
            refilter()
            state = .loaded
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
}
