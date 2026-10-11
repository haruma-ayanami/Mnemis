import Foundation

/// Значение слова для одной части речи: русские переводы, английское толкование и пример.
struct WordLookupSense: Equatable, Sendable {
    let partOfSpeech: String
    let translations: [String]
    let definition: String?
    let example: String?
}

/// Найденное слово: транскрипция и значения по частям речи в порядке Викисловаря.
struct WordLookupEntry: Equatable, Sendable {
    let lemma: String
    let ipa: String?
    let senses: [WordLookupSense]

    func sense(for partOfSpeech: String?) -> WordLookupSense? {
        senses.first { $0.partOfSpeech == partOfSpeech } ?? senses.first
    }
}

protocol WordLookupProvider: Sendable {
    func lookup(_ word: String) async throws -> WordLookupEntry?
}

/// Слова из английского Викисловаря через kaikki.org (CC BY-SA), тем же способом, что и идиомы.
struct WiktionaryWordProvider: WordLookupProvider {
    let client: APIClient
    let baseURL: URL

    init(client: APIClient = APIClient(), baseURL: URL = WiktionaryIdiomProvider.baseURL) {
        self.client = client
        self.baseURL = baseURL
    }

    func lookup(_ word: String) async throws -> WordLookupEntry? {
        let term = TextNormalizer.normalize(word)
        guard term.count >= 2, !term.contains(" "), let url = WiktionaryIdiomProvider.url(for: term, baseURL: baseURL) else { return nil }
        do {
            return WiktionaryWordParser.parse(try await client.data(from: url), term: term)
        } catch APIError.notFound {
            return nil
        }
    }
}

/// Разбор JSONL kaikki для слова. Отделён от сети, поэтому проверяется тестами на фикстурах.
enum WiktionaryWordParser {
    /// Части речи, которые приложение показывает. Имена собственные, символы и фразы пропускаются.
    static let partsOfSpeech: [String: String] = [
        "noun": "noun", "verb": "verb", "adj": "adjective", "adv": "adverb",
        "prep": "preposition", "pron": "pronoun", "conj": "conjunction", "intj": "interjection",
    ]
    /// Значения, которые не годятся как основное: формы других слов, устаревшие и ошибочные написания.
    private static let skippedTags: Set<String> = ["form-of", "alt-of", "misspelling", "obsolete", "archaic"]
    private static let maxTranslations = 4

    static func parse(_ data: Data, term: String) -> WordLookupEntry? {
        let decoder = JSONDecoder()
        let entries = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { try? decoder.decode(Entry.self, from: Data($0.utf8)) }
            .filter { TextNormalizer.normalize($0.word) == term }

        var senses: [WordLookupSense] = []
        var ipaCandidates: [String] = []
        for entry in entries {
            guard let part = entry.pos.flatMap({ partsOfSpeech[$0] }), !senses.contains(where: { $0.partOfSpeech == part }) else { continue }
            let usable = (entry.senses ?? []).filter { sense in
                guard let gloss = sense.glosses?.first, !gloss.isEmpty else { return false }
                return Set(sense.tags ?? []).isDisjoint(with: skippedTags)
            }
            guard let first = usable.first else { continue }

            let definition = first.glosses?.first.map(trimmed)
            let example = usable
                .flatMap { $0.examples ?? [] }
                .compactMap(\.text)
                .map { $0.split(whereSeparator: \.isNewline).first.map(String.init) ?? $0 }
                .first { isGoodExample($0, term: term) }

            var translations: [String] = []
            for translation in entry.translations ?? [] where translation.langCode == "ru" {
                guard let word = translation.word.map(WiktionaryIdiomParser.stripStress), isGoodTranslation(word),
                      !translations.contains(word) else { continue }
                translations.append(word)
                if translations.count == maxTranslations { break }
            }

            senses.append(WordLookupSense(partOfSpeech: part, translations: translations, definition: definition, example: example))
            ipaCandidates += (entry.sounds ?? []).compactMap(\.ipa).filter { !$0.isEmpty }
        }
        guard !senses.isEmpty else { return nil }

        let ipa = ipaCandidates.first { $0.hasPrefix("/") } ?? ipaCandidates.first
        return WordLookupEntry(lemma: entries[0].word, ipa: ipa, senses: senses)
    }

    /// Пример нужен короткий и содержащий само слово (или его начало, если форма изменилась).
    private static func isGoodExample(_ text: String, term: String) -> Bool {
        guard text.count <= 160, !text.contains("ſ") else { return false }
        return text.localizedCaseInsensitiveContains(String(term.prefix(max(3, term.count - 2))))
    }

    /// Русское слово без латиницы и пояснений, до трёх слов.
    private static func isGoodTranslation(_ word: String) -> Bool {
        guard !word.isEmpty, word.split(separator: " ").count <= 3 else { return false }
        return word.lowercased().unicodeScalars.allSatisfy { ("а"..."я").contains(Character($0)) || $0 == "ё" || $0 == " " || $0 == "-" }
    }

    private static func trimmed(_ gloss: String) -> String {
        var text = gloss.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private struct Entry: Decodable {
        let word: String
        let pos: String?
        let senses: [Sense]?
        let translations: [Translation]?
        let sounds: [Sound]?
    }

    private struct Sense: Decodable {
        let glosses: [String]?
        let tags: [String]?
        let examples: [Example]?
    }

    private struct Example: Decodable {
        let text: String?
    }

    private struct Sound: Decodable {
        let ipa: String?
    }

    private struct Translation: Decodable {
        let langCode: String?
        let word: String?

        enum CodingKeys: String, CodingKey {
            case langCode = "lang_code"
            case word
        }
    }
}
