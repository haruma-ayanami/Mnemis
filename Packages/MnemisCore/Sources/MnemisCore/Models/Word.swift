import Foundation
import SwiftData

/// Запись словаря: встроенное слово, слово пользователя или кэш API.
/// Личный прогресс по слову хранится отдельно в `LearningProgress`.
///
/// Без `@Attribute(.unique)`: CloudKit его не поддерживает, уникальность проверяем в коде.
@Model
public final class Word {
    public var id: UUID
    public var lemma: String
    public var translation: String
    public var definition: String
    public var partOfSpeech: String
    public var ipa: String?
    public var audioURL: URL?
    public var examples: [String]
    public var synonyms: [String]
    public var antonyms: [String]
    public var level: String?
    public var frequency: Int?
    public var origin: WordOrigin
    /// Источник данных, например «Wiktionary» или «user».
    public var source: String
    /// Лицензия данных. Для встроенного словаря обязательна (ABOUT.md, раздел 13).
    public var license: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        lemma: String,
        translation: String = "",
        definition: String = "",
        partOfSpeech: String = "",
        ipa: String? = nil,
        audioURL: URL? = nil,
        examples: [String] = [],
        synonyms: [String] = [],
        antonyms: [String] = [],
        level: String? = nil,
        frequency: Int? = nil,
        origin: WordOrigin = .user,
        source: String = "user",
        license: String = "user-generated",
        createdAt: Date = .now
    ) {
        self.id = id
        self.lemma = lemma
        self.translation = translation
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.audioURL = audioURL
        self.examples = examples
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.level = level
        self.frequency = frequency
        self.origin = origin
        self.source = source
        self.license = license
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
