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
                meanings: item.meanings ?? [],
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

    /// Итог обновления встроенного словаря.
    struct RefreshResult: Equatable {
        var updated = 0
        var added = 0
        var removed = 0
    }

    /// Обновляет встроенные слова до новой версии словаря.
    ///
    /// - Слово, которое пользователь не правил, получает новые переводы, значения по частям речи и определение.
    ///   Правленое слово (`updatedAt` позже `createdAt`) не трогаем.
    /// - Новые слова добавляются, как при обычном импорте.
    /// - Встроенное слово, которого больше нет в словаре, удаляется, только если его ещё не начинали учить.
    @discardableResult
    func refresh(_ seed: SeedWords, manifest: SeedManifest, startedWordIDs: Set<UUID>, now: Date) throws -> RefreshResult {
        var result = RefreshResult()
        let items = Dictionary(seed.words.map { (TextNormalizer.normalize($0.lemma), $0) }, uniquingKeysWith: { first, _ in first })

        let existing = try words.updateBuiltIn(sourceID: seed.sourceID) { word in
            guard let item = items[word.normalizedLemma] else {
                guard !startedWordIDs.contains(word.id) else { return .keep }
                result.removed += 1
                return .delete
            }
            guard word.updatedAt <= word.createdAt else { return .keep }

            var updated = word
            updated.translation = item.translation
            updated.partOfSpeech = item.partOfSpeech
            updated.meanings = item.meanings ?? []
            updated.definition = item.definition ?? word.definition
            updated.ipa = item.ipa ?? word.ipa
            updated.level = item.level ?? word.level
            updated.frequencyRank = item.frequencyRank ?? word.frequencyRank
            guard updated != word else { return .keep }
            result.updated += 1
            return .update(updated)
        }
        let seen = existing

        let missing = SeedWords(sourceID: seed.sourceID, version: seed.version, words: seed.words.filter {
            !seen.contains(TextNormalizer.normalize($0.lemma))
        })
        result.added = try importWords(missing, manifest: manifest, now: now)
        try persistence.save()
        return result
    }
}
