import Foundation

/// Загружает встроенный словарь в базу. Повторный запуск ничего не дублирует:
/// слово с той же нормализованной формой пропускается.
@MainActor
struct SeedDataImporter {
    let words: WordRepository
    let persistence: PersistenceController

    /// - Returns: количество добавленных слов.
    @discardableResult
    func importWords(_ seed: SeedWords, manifest: SeedManifest, now: Date) throws -> Int {
        let licenseID = manifest.source(id: seed.sourceID)?.licenseID
        var known = Set(try words.allWords().map(\.normalizedLemma))
        var added = 0

        for item in seed.words {
            let key = TextNormalizer.normalize(item.lemma)
            guard !known.contains(key) else { continue }

            let word = Word(
                lemma: item.lemma,
                translation: item.translation,
                partOfSpeech: item.partOfSpeech,
                definition: item.definition,
                ipa: item.ipa,
                level: item.level,
                frequencyRank: item.frequencyRank,
                origin: .builtin,
                sourceID: seed.sourceID,
                licenseID: licenseID,
                createdAt: now
            )
            words.insert(word)

            for sentence in item.examples ?? [] {
                words.insert(ExampleSentence(
                    wordID: word.id,
                    sentence: sentence,
                    sourceID: seed.sourceID,
                    licenseID: licenseID,
                    isUserCreated: false,
                    createdAt: now
                ))
            }

            known.insert(key)
            added += 1
        }

        try persistence.save()
        return added
    }
}
