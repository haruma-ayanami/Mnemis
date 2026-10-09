import Foundation
import SwiftData

// SwiftData-схема. Классы здесь — только хранение. Логика живёт в доменных структурах,
// связь между ними — в `Mapping.swift` (ARCHITECTURE.md, разделы 1 и 8).
// Значения по умолчанию у всех полей и отсутствие `.unique` оставляют путь к CloudKit открытым.

@Model
final class WordEntity {
    var id: UUID = UUID()
    var lemma: String = ""
    var normalizedLemma: String = ""
    var learningLanguage: LanguageCode = LanguageCode.en
    var translationLanguage: LanguageCode = LanguageCode.ru
    var translation: String = ""
    var partOfSpeech: String?
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

    init(_ word: Word) {
        apply(word)
    }
}

@Model
final class ExampleSentenceEntity {
    var id: UUID = UUID()
    var wordID: UUID = UUID()
    var sentence: String = ""
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
    var proficiencyLevel: LanguageLevel = LanguageLevel.b1
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
    var onboardingCompleted: Bool = false

    init(_ settings: UserSettings) {
        apply(settings)
    }
}
