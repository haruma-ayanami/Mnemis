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

    private func entity(id: UUID) throws -> WordEntity? {
        try context.fetch(FetchDescriptor<WordEntity>(predicate: #Predicate { $0.id == id })).first
    }
}
