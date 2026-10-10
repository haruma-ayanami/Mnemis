import Foundation

/// Лексическая запись: что означает слово. Общая информация, не зависящая от пользователя.
/// Личный прогресс хранится отдельно в `WordProgress` (ARCHITECTURE.md, раздел 3).
struct Word: Identifiable, Equatable, Sendable {
    let id: UUID
    var lemma: String
    var learningLanguage: LanguageCode
    var translationLanguage: LanguageCode
    /// Основной перевод: перевод первой части речи. По нему идёт список слов и поиск.
    var translation: String
    var partOfSpeech: String?
    /// Значения по частям речи, например `book`: «noun · книга», «verb · бронировать».
    /// Пусто, если у слова одна часть речи: тогда хватает `translation` и `partOfSpeech`.
    var meanings: [WordMeaning]
    var definition: String?
    var ipa: String?
    var audioURL: URL?
    var level: String?
    var frequencyRank: Int?
    var origin: WordOrigin
    var sourceID: String?
    var licenseID: String?
    /// Личная заметка пользователя. Внешние данные её не трогают.
    var userNote: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        lemma: String,
        learningLanguage: LanguageCode = .en,
        translationLanguage: LanguageCode = .ru,
        translation: String = "",
        partOfSpeech: String? = nil,
        meanings: [WordMeaning] = [],
        definition: String? = nil,
        ipa: String? = nil,
        audioURL: URL? = nil,
        level: String? = nil,
        frequencyRank: Int? = nil,
        origin: WordOrigin = .user,
        sourceID: String? = nil,
        licenseID: String? = nil,
        userNote: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.lemma = lemma
        self.learningLanguage = learningLanguage
        self.translationLanguage = translationLanguage
        self.translation = translation
        self.partOfSpeech = partOfSpeech
        self.meanings = meanings
        self.definition = definition
        self.ipa = ipa
        self.audioURL = audioURL
        self.level = level
        self.frequencyRank = frequencyRank
        self.origin = origin
        self.sourceID = sourceID
        self.licenseID = licenseID
        self.userNote = userNote
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// Все значения для показа: части речи по порядку. Для слова без `meanings` — одно значение из `translation`.
    var allMeanings: [WordMeaning] {
        guard meanings.isEmpty else { return meanings }
        guard !translation.isEmpty else { return [] }
        return [WordMeaning(partOfSpeech: partOfSpeech ?? "", translation: translation)]
    }

    /// Идиома хранится как слово с частью речи `idiom`: прогресс, статусы и повторения у неё такие же.
    var isIdiom: Bool { partOfSpeech == Word.idiomPartOfSpeech }

    /// Нормализованная форма для поиска и защиты от дублей.
    var normalizedLemma: String { TextNormalizer.normalize(lemma) }

    static let idiomPartOfSpeech = "idiom"
    /// Идиомы без частотного ранга попадают в очередь новых слов между частотными словами.
    static let idiomSortRank = 2500
}

/// Что показывает список словаря: слова или идиомы.
enum WordKind: Equatable, Sendable {
    case words
    case idioms

    var isIdiom: Bool { self == .idioms }
}

/// Перевод для одной части речи.
struct WordMeaning: Codable, Equatable, Sendable {
    var partOfSpeech: String
    var translation: String

    /// Короткая метка части речи для карточек: `n`, `v`, `adj`, `adv`, `prep`.
    var shortPartOfSpeech: String {
        switch partOfSpeech {
        case "noun": "n"
        case "verb": "v"
        case "adjective": "adj"
        case "adverb": "adv"
        case "preposition": "prep"
        default: partOfSpeech
        }
    }
}
