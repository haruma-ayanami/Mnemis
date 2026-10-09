import Foundation

enum EnrichmentOutcome: Equatable {
    case updated(fieldsAdded: Int)
    /// Источник ответил, но добавлять нечего: все поля уже заполнены.
    case nothingToAdd
    case notFound
    /// Сеть недоступна. Слово при этом не теряется и не меняется.
    case unavailable
}

/// Дополняет слово данными из источников (ARCHITECTURE.md, раздел 7).
/// Заполняет только пустые поля. Пользовательские значения и примеры не перезаписываются.
@MainActor
struct WordEnrichment {
    let dictionary: DictionaryService
    let words: WordRepository
    let persistence: PersistenceController
    let clock: any Clock

    func enrich(wordID: UUID) async throws -> EnrichmentOutcome {
        guard var word = try words.word(id: wordID) else { return .notFound }

        let entry: DictionaryEntry
        switch await dictionary.lookup(word.lemma) {
        case .found(let found):
            entry = found
        case .notFound:
            return .notFound
        case .unavailable:
            return .unavailable
        }

        var added = 0
        if word.ipa == nil, let ipa = entry.ipa {
            word.ipa = ipa
            added += 1
        }
        if word.audioURL == nil, let audio = entry.audioURL {
            word.audioURL = audio
            added += 1
        }
        if word.partOfSpeech == nil, let partOfSpeech = entry.partOfSpeech {
            word.partOfSpeech = partOfSpeech
            added += 1
        }
        if (word.definition ?? "").isEmpty, let definition = entry.definition {
            word.definition = definition
            added += 1
        }

        let existingSentences = Set(try words.examples(forWordID: wordID).map(\.sentence))
        for sentence in entry.examples where !existingSentences.contains(sentence) {
            words.insert(ExampleSentence(
                wordID: wordID,
                sentence: sentence,
                sourceID: entry.sourceID,
                licenseID: entry.licenseID,
                isUserCreated: false,
                createdAt: clock.now
            ))
            added += 1
        }

        guard added > 0 else { return .nothingToAdd }

        word.updatedAt = clock.now
        try words.upsert(word)
        try persistence.save()
        return .updated(fieldsAdded: added)
    }
}
