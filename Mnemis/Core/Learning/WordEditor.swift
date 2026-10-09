import Foundation

enum WordEditorError: Error, Equatable {
    case emptyLemma
    /// Такое слово уже есть. Передаём id существующей записи, чтобы UI мог её открыть.
    case duplicate(UUID)
}

/// Добавление и редактирование слов. Работает без сети: данные можно дополнить позже.
@MainActor
struct WordEditor {
    let words: WordRepository
    let persistence: PersistenceController
    let clock: any Clock

    @discardableResult
    func addWord(lemma: String, translation: String) throws -> Word {
        let trimmedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLemma.isEmpty else { throw WordEditorError.emptyLemma }

        let key = TextNormalizer.normalize(trimmedLemma)
        if let existing = try words.allWords().first(where: { $0.normalizedLemma == key }) {
            throw WordEditorError.duplicate(existing.id)
        }

        let word = Word(
            lemma: trimmedLemma,
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            origin: .user,
            sourceID: "user",
            createdAt: clock.now
        )
        try words.upsert(word)
        try persistence.save()
        return word
    }

    func update(_ word: Word) throws {
        var updated = word
        updated.updatedAt = clock.now
        try words.upsert(updated)
        try persistence.save()
    }

    /// Пользовательский пример хранится отдельно и никогда не перезаписывается данными из API.
    func addExample(wordID: UUID, sentence: String) throws {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        words.insert(ExampleSentence(
            wordID: wordID,
            sentence: trimmed,
            isUserCreated: true,
            createdAt: clock.now
        ))
        try persistence.save()
    }
}
