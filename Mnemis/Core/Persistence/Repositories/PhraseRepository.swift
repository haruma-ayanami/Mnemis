import Foundation
import SwiftData

/// Личные идиомы. Поиск только по тому, что сохранено у пользователя: идиома, значение, пример.
@MainActor
struct PhraseRepository {
    let context: ModelContext

    func all() throws -> [Phrase] {
        let descriptor = FetchDescriptor<PhraseEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).map(\.domain)
    }

    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<PhraseEntity>())
    }

    /// Поиск по тексту, значению и примеру. Пустой запрос возвращает весь список.
    func search(_ query: String) throws -> [Phrase] {
        let needle = TextNormalizer.normalize(query)
        guard !needle.isEmpty else { return try all() }
        let entities = try context.fetch(FetchDescriptor<PhraseEntity>(
            predicate: #Predicate { $0.searchText.contains(needle) },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        return entities.map(\.domain)
    }

    /// Идиома с тем же текстом (без учёта регистра и лишних пробелов), чтобы не сохранить её дважды.
    func phrase(text: String) throws -> Phrase? {
        let normalized = TextNormalizer.normalize(text)
        return try search(normalized).first { TextNormalizer.normalize($0.text) == normalized }
    }

    func phrase(id: UUID) throws -> Phrase? {
        try entity(id: id)?.domain
    }

    func insert(_ phrase: Phrase) {
        context.insert(PhraseEntity(phrase))
    }

    func update(_ phrase: Phrase) throws {
        guard let existing = try entity(id: phrase.id) else { return }
        existing.apply(phrase)
    }

    func delete(id: UUID) throws {
        guard let existing = try entity(id: id) else { return }
        context.delete(existing)
    }

    /// Идиома дня: детерминированно по дню, чтобы она не менялась в течение дня. Пустой список даёт nil.
    /// Сначала выбирается из идиом, которые пользователь ещё учит; если все отмечены «знаю» — из всех.
    func phraseOfDay(dayID: String) throws -> Phrase? {
        let all = try all()
        let learning = all.filter { !$0.isKnown }
        let phrases = (learning.isEmpty ? all : learning).sorted { $0.id.uuidString < $1.id.uuidString }
        guard !phrases.isEmpty else { return nil }
        return phrases[Int(DailyWordSelector.fnv1a(dayID) % UInt64(phrases.count))]
    }

    private func entity(id: UUID) throws -> PhraseEntity? {
        try context.fetch(FetchDescriptor<PhraseEntity>(predicate: #Predicate { $0.id == id })).first
    }
}
