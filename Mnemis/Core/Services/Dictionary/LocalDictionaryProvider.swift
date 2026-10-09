import Foundation

/// Локальные данные: встроенный словарь и кэш ответов API. Пользовательские слова сюда не входят:
/// они не должны считаться «найденными» и блокировать обогащение из источников.
@MainActor
struct LocalDictionaryProvider: DictionaryProvider {
    let sourceID = "local"
    let words: WordRepository

    func entry(for lemma: String) async throws -> DictionaryEntry? {
        let key = TextNormalizer.normalize(lemma)
        guard let word = try words.words(normalizedLemma: key).first(where: { $0.origin != .user }) else { return nil }

        let examples = try words.examples(forWordID: word.id)
            .filter { !$0.isUserCreated }
            .map(\.sentence)

        return DictionaryEntry(
            lemma: word.lemma,
            ipa: word.ipa,
            audioURL: word.audioURL,
            partOfSpeech: word.partOfSpeech,
            definition: word.definition,
            examples: examples,
            sourceID: word.sourceID ?? sourceID,
            licenseID: word.licenseID ?? ""
        )
    }
}
