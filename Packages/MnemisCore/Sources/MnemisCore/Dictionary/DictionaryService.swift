import Foundation

/// Сведения о слове из внешнего источника. Перед сохранением превращается в `Word`.
public struct DictionaryEntry: Equatable, Sendable {
    public struct Meaning: Equatable, Sendable {
        public var partOfSpeech: String
        public var definition: String
        public var example: String?
        public var synonyms: [String]
        public var antonyms: [String]

        public init(partOfSpeech: String, definition: String, example: String?, synonyms: [String], antonyms: [String]) {
            self.partOfSpeech = partOfSpeech
            self.definition = definition
            self.example = example
            self.synonyms = synonyms
            self.antonyms = antonyms
        }
    }

    public var lemma: String
    public var ipa: String?
    public var audioURL: URL?
    public var meanings: [Meaning]

    public init(lemma: String, ipa: String?, audioURL: URL?, meanings: [Meaning]) {
        self.lemma = lemma
        self.ipa = ipa
        self.audioURL = audioURL
        self.meanings = meanings
    }
}

// MARK: - Протоколы (ABOUT.md, раздел 11)
// UI зависит только от протоколов. Конкретный API можно заменить без правок View.

/// Определения и примеры. Реализации: онлайн-API, локальный словарь.
public protocol DictionaryService: Sendable {
    /// Возвращает `nil`, если слово не найдено.
    func entry(for lemma: String) async throws -> DictionaryEntry?
}

public protocol TranslationService: Sendable {
    func translate(_ text: String, from source: String, to target: String) async throws -> String?
}

public protocol ExampleSentenceService: Sendable {
    func examples(for lemma: String) async throws -> [String]
}

public protocol PronunciationService: Sendable {
    func audioURL(for lemma: String) async throws -> URL?
}

extension Word {
    /// Создаёт кэш-запись из ответа внешнего источника (`origin = .api`).
    public static func make(from entry: DictionaryEntry, source: String, license: String) -> Word {
        let firstMeaning = entry.meanings.first
        return Word(
            lemma: entry.lemma,
            definition: firstMeaning?.definition ?? "",
            partOfSpeech: firstMeaning?.partOfSpeech ?? "",
            ipa: entry.ipa,
            audioURL: entry.audioURL,
            examples: entry.meanings.compactMap(\.example),
            synonyms: Array(Set(entry.meanings.flatMap(\.synonyms))).sorted(),
            antonyms: Array(Set(entry.meanings.flatMap(\.antonyms))).sorted(),
            origin: .api,
            source: source,
            license: license
        )
    }
}
