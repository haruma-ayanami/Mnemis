import Foundation
import SwiftData

// SwiftData-схема. Классы здесь — только хранение. Логика живёт в доменных структурах,
// связь между ними — в `Mapping.swift` (ARCHITECTURE.md, разделы 1 и 8).
// Значения по умолчанию у всех полей и отсутствие `.unique` оставляют путь к CloudKit открытым.

@Model
final class WordEntity {
    // Индексы под реальные выборки: поиск по лемме, очередь новых слов, дубликаты при добавлении.
    #Index<WordEntity>([\.normalizedLemma], [\.isAPIOrigin, \.isStarted, \.sortRank])

    var id: UUID = UUID()
    var lemma: String = ""
    var normalizedLemma: String = ""
    var learningLanguage: LanguageCode = LanguageCode.en
    var translationLanguage: LanguageCode = LanguageCode.ru
    var translation: String = ""
    var partOfSpeech: String?
    /// Значения по частям речи в JSON (`[WordMeaning]`). Пустая строка — одно значение в `translation`.
    var meaningsJSON: String = ""
    var definition: String?
    var ipa: String?
    var audioURL: URL?
    var level: String?
    var frequencyRank: Int?
    var origin: WordOrigin = WordOrigin.user
    var sourceID: String?
    var licenseID: String?
    var userNote: String?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // Производные поля для быстрых выборок. Пересчитываются в `apply`, `isStarted` ведёт ProgressRepository.
    var isAPIOrigin: Bool = false
    var sortRank: Int = Int.max
    var isStarted: Bool = false
    /// Перевод, определение и заметка в нижнем регистре: поиск идёт по базе, а не по словам в памяти.
    var searchText: String = ""

    init(_ word: Word) {
        apply(word)
    }
}

@Model
final class ExampleSentenceEntity {
    #Index<ExampleSentenceEntity>([\.wordID])

    var id: UUID = UUID()
    var wordID: UUID = UUID()
    var sentence: String = ""
    /// Предложение в нижнем регистре для поиска по пользовательским примерам.
    var searchText: String = ""
    var translation: String?
    var sourceID: String?
    var licenseID: String?
    var isUserCreated: Bool = false
    var createdAt: Date = Date.now

    init(_ example: ExampleSentence) {
        apply(example)
    }
}

@Model
final class WordProgressEntity {
    #Index<WordProgressEntity>([\.wordID], [\.dueAt], [\.isSchedulable, \.dueAt], [\.statusRaw], [\.introducedSortKey])

    var id: UUID = UUID()
    var wordID: UUID = UUID()
    var status: LearningStatus = LearningStatus.new
    var repetitionCount: Int = 0
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var difficulty: Double = 2.5
    var stability: Double = 0
    var intervalDays: Double = 0
    var lastReviewedAt: Date?
    var nextReviewAt: Date?
    var introducedAt: Date?
    var suspendedFromStatus: LearningStatus?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // Производные поля для запросов: счётчики и очередь берутся из базы, а не из всего прогресса.
    // Пересчитываются в `apply`; запись прогресса идёт только через ProgressRepository.
    var statusRaw: String = LearningStatus.new.rawValue
    var isSchedulable: Bool = true
    var isMastered: Bool = false
    /// `nextReviewAt` или «далёкое будущее», если повторения нет: так условие `dueAt <= now` не требует опционалов.
    var dueAt: Date = Date.distantFuture
    /// `introducedAt` или «далёкое прошлое», если слово ещё не введено в учёт.
    var introducedSortKey: Date = Date.distantPast

    init(_ progress: WordProgress) {
        apply(progress)
    }
}

@Model
final class ReviewRecordEntity {
    var id: UUID = UUID()
    var wordID: UUID = UUID()
    var reviewedAt: Date = Date.now
    var rating: ReviewRating = ReviewRating.good
    var previousIntervalDays: Double = 0
    var scheduledIntervalDays: Double = 0
    var responseDurationMilliseconds: Int?
    var sessionID: UUID?

    init(_ record: ReviewRecord) {
        apply(record)
    }
}

@Model
final class DailyWordAssignmentEntity {
    #Index<DailyWordAssignmentEntity>([\.localDayID])

    var id: UUID = UUID()
    var localDayID: String = ""
    var wordID: UUID = UUID()
    var assignedAt: Date = Date.now
    var timeZoneIdentifier: String = ""

    init(_ assignment: DailyWordAssignment) {
        apply(assignment)
    }
}

@Model
final class UserSettingsEntity {
    var id: UUID = UUID()
    var learningLanguage: LanguageCode = LanguageCode.en
    var translationLanguage: LanguageCode = LanguageCode.ru
    /// Уровень храним строкой: значения старых версий (например, «IELTS») не должны ронять чтение базы.
    var proficiencyLevelRaw: String = LanguageLevel.b1.rawValue
    var proficiencyLevel: LanguageLevel {
        get { LanguageLevel.stored(proficiencyLevelRaw) }
        set { proficiencyLevelRaw = newValue.rawValue }
    }
    var newWordsPerDay: Int = 5
    var dailyReminderEnabled: Bool = false
    var dailyReminderMinutes: Int = 540
    var notifyWordOfDay: Bool = true
    var notifyReviews: Bool = true
    var notifyStreak: Bool = true
    var notificationWeekdays: Int = 127
    var maxNotificationsPerDay: Int = 2
    var preferredTheme: ThemePreference = ThemePreference.system
    var soundEnabled: Bool = true
    var phrasesInToday: Bool = true
    var onboardingCompleted: Bool = false

    init(_ settings: UserSettings) {
        apply(settings)
    }
}

@Model
final class DailyActivityEntity {
    #Index<DailyActivityEntity>([\.localDayID], [\.dayStart])

    var id: UUID = UUID()
    var localDayID: String = ""
    var dayStart: Date = Date.now
    var reviewCount: Int = 0
    var correctCount: Int = 0

    init(_ activity: DailyActivity) {
        apply(activity)
    }
}

@Model
final class PhraseEntity {
    #Index<PhraseEntity>([\.createdAt])

    var id: UUID = UUID()
    static let idiomKind = "idiom"

    var kindRaw: String = PhraseEntity.idiomKind
    var text: String = ""
    var meaning: String = ""
    var example: String?
    /// Свои примеры пользователя в JSON (`[String]`). Пустая строка — примеров нет.
    var userExamplesJSON: String = ""
    var note: String?
    var isKnown: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    /// Текст, по которому идёт поиск: в нижнем регистре, без лишних пробелов.
    var searchText: String = ""

    init(_ phrase: Phrase) {
        apply(phrase)
    }
}
