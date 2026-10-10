import Foundation
import SwiftData

/// Доступ к словарю и примерам. Сам не сохраняет: запись фиксирует use case через `PersistenceController.save()`.
@MainActor
struct WordRepository {
    let context: ModelContext

    func allWords() throws -> [Word] {
        try context.fetch(FetchDescriptor<WordEntity>()).map(\.domain)
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<WordEntity>())
    }

    func word(id: UUID) throws -> Word? {
        try entity(id: id)?.domain
    }

    /// Добавляет новое слово без проверки на существование: для массового импорта.
    func insert(_ word: Word) {
        context.insert(WordEntity(word))
    }

    /// Обновляет существующее слово или добавляет новое.
    func upsert(_ word: Word) throws {
        if let existing = try entity(id: word.id) {
            existing.apply(word)
        } else {
            context.insert(WordEntity(word))
        }
    }

    /// Что сделать со встроенным словом при обновлении словаря.
    enum BatchChange {
        case keep
        case update(Word)
        case delete
    }

    /// Проходит по встроенным словам источника одним запросом и меняет записи на месте.
    /// Нужен для обновления словаря: тысячи `upsert` с поиском по id каждый раз слишком медленные.
    /// - Returns: нормализованные леммы всех встроенных слов источника, включая удалённые.
    @discardableResult
    func updateBuiltIn(sourceID: String, _ change: (Word) throws -> BatchChange) throws -> Set<String> {
        // Происхождение хранится enum-ом, его в предикат не передаём: фильтруем по источнику в базе, остальное здесь.
        let entities = try context.fetch(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.sourceID == sourceID }))
        var lemmas = Set<String>()
        var deleted: [UUID] = []
        for entity in entities where entity.origin == .builtin {
            lemmas.insert(entity.normalizedLemma)
            switch try change(entity.domain) {
            case .keep:
                break
            case .update(let word):
                entity.apply(word)
            case .delete:
                deleted.append(entity.id)
                context.delete(entity)
            }
        }
        if !deleted.isEmpty {
            for example in try context.fetch(FetchDescriptor<ExampleSentenceEntity>(predicate: #Predicate { deleted.contains($0.wordID) })) {
                context.delete(example)
            }
        }
        return lemmas
    }

    /// Удаляет слово вместе с его примерами. Прогресс не трогает: вызывающий код удаляет только не начатые слова.
    func delete(id: UUID) throws {
        guard let existing = try entity(id: id) else { return }
        for example in try context.fetch(FetchDescriptor<ExampleSentenceEntity>(predicate: #Predicate { $0.wordID == id })) {
            context.delete(example)
        }
        context.delete(existing)
    }

    func examples(forWordID wordID: UUID) throws -> [ExampleSentence] {
        try context.fetch(
            FetchDescriptor<ExampleSentenceEntity>(
                predicate: #Predicate { $0.wordID == wordID },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        ).map(\.domain)
    }

    func allExamples() throws -> [ExampleSentence] {
        try context.fetch(FetchDescriptor<ExampleSentenceEntity>()).map(\.domain)
    }

    func insert(_ example: ExampleSentence) {
        context.insert(ExampleSentenceEntity(example))
    }

    /// Слова с такой нормализованной леммой. Индексированный запрос вместо перебора словаря; обычно это одна запись.
    func words(normalizedLemma key: String) throws -> [Word] {
        try context.fetch(
            FetchDescriptor<WordEntity>(predicate: #Predicate { $0.normalizedLemma == key })
        ).map(\.domain)
    }

    /// Количество слов без кэша API: то, что показываем как «всего слов».
    func countOwnAndBuiltIn() throws -> Int {
        try context.fetchCount(FetchDescriptor<WordEntity>(predicate: #Predicate { !$0.isAPIOrigin }))
    }

    /// Слова по списку id: повторения сегодня и Daily Word. Словарь целиком не читаем.
    func words(ids: [UUID]) throws -> [Word] {
        guard !ids.isEmpty else { return [] }
        return try context.fetch(
            FetchDescriptor<WordEntity>(predicate: #Predicate { ids.contains($0.id) })
        ).map(\.domain)
    }

    /// Первые ещё не начатые слова по частотности: кандидаты на новые слова дня.
    /// Порядок совпадает с `LearningSession`: частотность, затем лемма.
    func freshCandidates(limit: Int) throws -> [Word] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<WordEntity>(
            predicate: #Predicate { !$0.isAPIOrigin && !$0.isStarted },
            sortBy: [SortDescriptor(\.sortRank), SortDescriptor(\.lemma)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map(\.domain)
    }

    /// Поиск по базе: сначала слова, которые начинаются с запроса, затем содержащие его в лемме,
    /// переводе, определении, заметке и пользовательских примерах. Словарь целиком в память не читаем.
    func search(_ query: String, limit: Int, kind: WordKind? = nil) throws -> [Word] {
        let needle = TextNormalizer.normalize(query)
        guard !needle.isEmpty, limit > 0 else { return [] }

        var found: [UUID: (word: Word, score: Int)] = [:]
        func add(_ entities: [WordEntity], score: Int) {
            for entity in entities where (found[entity.id]?.score ?? Int.max) > score {
                found[entity.id] = (entity.domain, score)
            }
        }
        func fetchWords(_ predicate: Predicate<WordEntity>) throws -> [WordEntity] {
            var descriptor = FetchDescriptor<WordEntity>(predicate: predicate)
            descriptor.fetchLimit = limit
            return try context.fetch(descriptor)
        }

        // Точное совпадение леммы идёт первым, затем начинающиеся с запроса (они лежат подряд в алфавитном порядке).
        add(try fetchWords(#Predicate { $0.normalizedLemma == needle }), score: -1)
        let upper = needle + "\u{FFFF}"
        add(try fetchWords(#Predicate { $0.normalizedLemma >= needle && $0.normalizedLemma < upper }), score: 0)
        add(try fetchWords(#Predicate { $0.normalizedLemma.contains(needle) }), score: 1)
        add(try fetchWords(#Predicate { $0.searchText.contains(needle) }), score: 2)

        let exampleWordIDs = try context.fetch(
            FetchDescriptor<ExampleSentenceEntity>(predicate: #Predicate { $0.isUserCreated && $0.searchText.contains(needle) })
        ).map(\.wordID)
        if !exampleWordIDs.isEmpty {
            add(try fetchWords(#Predicate { exampleWordIDs.contains($0.id) }), score: 2)
        }

        return found.values
            .filter { kind == nil || $0.word.isIdiom == kind?.isIdiom }
            .sorted { ($0.score, $0.word.lemma) < ($1.score, $1.word.lemma) }
            .prefix(limit)
            .map(\.word)
    }

    /// Страница словаря по алфавиту. Смещение и размер страницы применяет база.
    func page(offset: Int, limit: Int, onlyNotStarted: Bool = false, kind: WordKind? = nil) throws -> [Word] {
        var descriptor: FetchDescriptor<WordEntity>
        if let kind {
            let idioms = kind.isIdiom
            descriptor = FetchDescriptor<WordEntity>(
                predicate: #Predicate { $0.isIdiom == idioms && (!onlyNotStarted || !$0.isStarted) },
                sortBy: [SortDescriptor(\.normalizedLemma)]
            )
        } else {
            descriptor = FetchDescriptor<WordEntity>(
                predicate: #Predicate { !onlyNotStarted || !$0.isStarted },
                sortBy: [SortDescriptor(\.normalizedLemma)]
            )
        }
        descriptor.fetchOffset = offset
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map(\.domain)
    }

    /// Все идиомы словаря: их немного, поэтому список целиком (для идиомы дня).
    func idioms() throws -> [Word] {
        try context.fetch(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.isIdiom })).map(\.domain)
    }

    /// Слова или идиомы, которые ещё не начаты.
    func countNotStarted(kind: WordKind) throws -> Int {
        let idioms = kind.isIdiom
        return try context.fetchCount(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.isIdiom == idioms && !$0.isStarted }))
    }

    /// Сколько слов или идиом в словаре.
    func count(kind: WordKind) throws -> Int {
        let idioms = kind.isIdiom
        return try context.fetchCount(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.isIdiom == idioms }))
    }

    /// Сколько слов из списка относятся к виду. Для счётчиков статусов по разделам.
    func count(kind: WordKind, ids: [UUID]) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let idioms = kind.isIdiom
        return try context.fetchCount(FetchDescriptor<WordEntity>(
            predicate: #Predicate { ids.contains($0.id) && $0.isIdiom == idioms }
        ))
    }

    /// Случайная выборка для отвлекающих вариантов в упражнениях: три страницы по случайному смещению.
    func sample(limit: Int, using random: inout some RandomNumberGenerator) throws -> [Word] {
        let total = try countAll()
        guard total > 0, limit > 0 else { return [] }
        let perPage = max(1, limit / 3)
        var result: [Word] = []
        for _ in 0..<3 {
            let offset = total > perPage ? Int.random(in: 0..<(total - perPage), using: &random) : 0
            result += try page(offset: offset, limit: perPage)
        }
        return result
    }

    func countAll() throws -> Int {
        try context.fetchCount(FetchDescriptor<WordEntity>())
    }

    /// Слова, которые ещё не начаты: статус «new» без записи прогресса.
    func countNotStarted() throws -> Int {
        try context.fetchCount(FetchDescriptor<WordEntity>(predicate: #Predicate { !$0.isStarted }))
    }

    /// Сколько слов встроенного словаря относится к уровню CEFR.
    func countWords(level: String) throws -> Int {
        try context.fetchCount(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.level == level }))
    }

    /// Сколько слов из списка относятся к уровню CEFR. Для прогресса «освоено на уровне».
    func countWords(level: String, ids: [UUID]) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        return try context.fetchCount(FetchDescriptor<WordEntity>(
            predicate: #Predicate { ids.contains($0.id) && $0.level == level }
        ))
    }

    /// Сколько новых слов доступно для очереди: не начатые и не из кэша API.
    func countFreshCandidates() throws -> Int {
        try context.fetchCount(FetchDescriptor<WordEntity>(predicate: #Predicate { !$0.isAPIOrigin && !$0.isStarted }))
    }

    /// Пересчитывает производные поля слов и примеров. Нужно один раз после обновления схемы.
    func refreshDerivedFields() throws {
        for entity in try context.fetch(FetchDescriptor<WordEntity>()) {
            entity.apply(entity.domain)
        }
        for entity in try context.fetch(FetchDescriptor<ExampleSentenceEntity>()) {
            entity.apply(entity.domain)
        }
    }

    private func entity(id: UUID) throws -> WordEntity? {
        try context.fetch(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.id == id })).first
    }
}
