import Foundation

enum PhraseEditorError: LocalizedError, Equatable {
    case emptyText
    case emptyMeaning
    case duplicate

    var errorDescription: String? {
        switch self {
        case .emptyText: String(localized: "Write the idiom.")
        case .emptyMeaning: String(localized: "Add the meaning, so you can recall it.")
        case .duplicate: String(localized: "This idiom is already in your list.")
        }
    }
}

/// Добавление, правка и удаление личных идиом (ABOUT.md, раздел 9.1).
@MainActor
struct PhraseEditor {
    let phrases: PhraseRepository
    let persistence: PersistenceController
    let clock: any Clock

    @discardableResult
    func add(text: String, meaning: String, example: String? = nil) throws -> Phrase {
        let text = try cleaned(text, orThrow: .emptyText)
        guard try phrases.phrase(text: text) == nil else { throw PhraseEditorError.duplicate }
        let phrase = Phrase(
            text: text,
            meaning: try cleaned(meaning, orThrow: .emptyMeaning),
            example: optionalCleaned(example),
            createdAt: clock.now
        )
        phrases.insert(phrase)
        try persistence.save()
        return phrase
    }

    func update(_ phrase: Phrase) throws {
        var updated = phrase
        updated.text = try cleaned(phrase.text, orThrow: .emptyText)
        updated.meaning = try cleaned(phrase.meaning, orThrow: .emptyMeaning)
        updated.example = optionalCleaned(phrase.example)
        updated.note = optionalCleaned(phrase.note)
        updated.updatedAt = clock.now
        try phrases.update(updated)
        try persistence.save()
    }

    /// Свой пример к идиоме. Пустой и повторный пример не добавляется.
    func addExample(_ sentence: String, to phrase: Phrase) throws -> Phrase {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != phrase.example, !phrase.userExamples.contains(trimmed) else { return phrase }
        var updated = phrase
        updated.userExamples.append(trimmed)
        try update(updated)
        return updated
    }

    func removeExample(at index: Int, from phrase: Phrase) throws -> Phrase {
        guard phrase.userExamples.indices.contains(index) else { return phrase }
        var updated = phrase
        updated.userExamples.remove(at: index)
        try update(updated)
        return updated
    }

    func setKnown(_ known: Bool, for phrase: Phrase) throws -> Phrase {
        var updated = phrase
        updated.isKnown = known
        try update(updated)
        return updated
    }

    func setNote(_ note: String, for phrase: Phrase) throws -> Phrase {
        var updated = phrase
        updated.note = optionalCleaned(note)
        try update(updated)
        return updated
    }

    func delete(id: UUID) throws {
        try phrases.delete(id: id)
        try persistence.save()
    }

    private func cleaned(_ value: String, orThrow error: PhraseEditorError) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw error }
        return trimmed
    }

    private func optionalCleaned(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
