import Foundation

enum WordEditorError: LocalizedError, Equatable {
    case emptyLemma
    case emptyMeaning
    /// Такое слово уже есть. Передаём id существующей записи, чтобы UI мог её открыть.
    case duplicate(UUID)
    /// Встроенные слова и идиомы удаляются только через обновление словаря, не вручную.
    case builtIn

    var errorDescription: String? {
        switch self {
        case .emptyLemma: String(localized: "Write the word or idiom.")
        case .emptyMeaning: String(localized: "Add the meaning, so you can recall it.")
        case .duplicate: String(localized: "This word is already in your list.")
        case .builtIn: String(localized: "Built-in entries can't be deleted.")
        }
    }
}

/// Поля, которые форма добавления может заполнить кроме слова и перевода.
struct NewEntryDetails: Equatable, Sendable {
    var partOfSpeech: String?
    var level: String?
    var ipa: String?
    var definition: String?
    /// Часть данных подставлена из Викисловаря: запись получает его лицензию (CC BY-SA).
    var fromWiktionary = false
}

/// Добавление и редактирование слов. Работает без сети: данные можно дополнить позже.
@MainActor
struct WordEditor {
    let words: WordRepository
    let progress: ProgressRepository
    let persistence: PersistenceController
    let clock: any Clock

    @discardableResult
    func addWord(lemma: String, translation: String, example: String? = nil, details: NewEntryDetails = NewEntryDetails()) throws -> Word {
        let trimmedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLemma.isEmpty else { throw WordEditorError.emptyLemma }

        let key = TextNormalizer.normalize(trimmedLemma)
        if let existing = try words.words(normalizedLemma: key).first {
            throw WordEditorError.duplicate(existing.id)
        }

        let word = Word(
            lemma: trimmedLemma,
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            partOfSpeech: details.partOfSpeech?.nilIfBlank,
            definition: details.definition?.nilIfBlank,
            ipa: details.ipa?.nilIfBlank,
            level: details.level,
            origin: .user,
            sourceID: "user",
            licenseID: details.fromWiktionary ? WiktionaryIdiomProvider.licenseID : nil,
            createdAt: clock.now
        )
        try words.upsert(word)
        insertExample(example, wordID: word.id)
        try persistence.save()
        return word
    }

    /// Идиома: слово с частью речи `idiom`. Значение пишет пользователь или берёт из Викисловаря,
    /// пример (необязательный) хранится как пользовательский.
    @discardableResult
    func addIdiom(text: String, meaning: String, example: String? = nil, details: NewEntryDetails = NewEntryDetails()) throws -> Word {
        let lemma = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lemma.isEmpty else { throw WordEditorError.emptyLemma }
        let value = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw WordEditorError.emptyMeaning }

        if let existing = try words.words(normalizedLemma: TextNormalizer.normalize(lemma)).first {
            throw WordEditorError.duplicate(existing.id)
        }
        let word = Word(
            lemma: lemma,
            translation: value,
            partOfSpeech: Word.idiomPartOfSpeech,
            definition: details.definition?.nilIfBlank,
            level: details.level,
            origin: .user,
            sourceID: "user",
            licenseID: details.fromWiktionary ? WiktionaryIdiomProvider.licenseID : nil,
            createdAt: clock.now
        )
        try words.upsert(word)
        insertExample(example, wordID: word.id)
        try persistence.save()
        return word
    }

    private func insertExample(_ example: String?, wordID: UUID) {
        guard let sentence = example?.nilIfBlank else { return }
        words.insert(ExampleSentence(wordID: wordID, sentence: sentence, isUserCreated: true, createdAt: clock.now))
    }

    /// Удаляет слово или идиому пользователя вместе с примерами и прогрессом.
    func delete(_ word: Word) throws {
        guard word.origin == .user else { throw WordEditorError.builtIn }
        try progress.delete(wordID: word.id)
        try words.delete(id: word.id)
        try persistence.save()
    }

    func update(_ word: Word) throws {
        var updated = word
        updated.updatedAt = clock.now
        // Правленый перевод — это перевод первой части речи: списки и карточки показывают одно и то же.
        if !updated.meanings.isEmpty {
            updated.meanings[0].translation = updated.translation
        }
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

private extension String {
    /// Строка без пробелов по краям, а пустая становится `nil`.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
