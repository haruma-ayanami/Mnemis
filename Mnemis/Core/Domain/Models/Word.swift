import Foundation

/// Лексическая запись: что означает слово. Общая информация, не зависящая от пользователя.
/// Личный прогресс хранится отдельно в `WordProgress` (ARCHITECTURE.md, раздел 3).
struct Word: Identifiable, Equatable, Sendable {
    let id: UUID
    var lemma: String
    var learningLanguage: LanguageCode
    var translationLanguage: LanguageCode
    /// Основной перевод. Несколько значений (`WordMeaning`) — после MVP.
    var translation: String
    var partOfSpeech: String?
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

    /// Нормализованная форма для поиска и защиты от дублей.
    var normalizedLemma: String { TextNormalizer.normalize(lemma) }
}
