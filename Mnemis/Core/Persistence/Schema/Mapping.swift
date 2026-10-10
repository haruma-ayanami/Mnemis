import Foundation

// Двусторонний маппинг: SwiftData-класс ⇄ доменная структура.
// Внешние DTO сюда не попадают: они преобразуются в доменные структуры в своих провайдерах.

extension WordEntity {
    func apply(_ word: Word) {
        id = word.id
        lemma = word.lemma
        normalizedLemma = word.normalizedLemma
        learningLanguage = word.learningLanguage
        translationLanguage = word.translationLanguage
        translation = word.translation
        partOfSpeech = word.partOfSpeech
        meaningsJSON = Self.encode(word.meanings)
        definition = word.definition
        ipa = word.ipa
        audioURL = word.audioURL
        level = word.level
        frequencyRank = word.frequencyRank
        origin = word.origin
        sourceID = word.sourceID
        licenseID = word.licenseID
        userNote = word.userNote
        createdAt = word.createdAt
        updatedAt = word.updatedAt
        isAPIOrigin = word.origin == .api
        isIdiom = word.isIdiom
        sortRank = word.frequencyRank ?? (word.isIdiom ? Word.idiomSortRank : Int.max)
        searchText = ([word.translation] + word.meanings.map(\.translation) + [word.definition ?? "", word.userNote ?? ""])
            .joined(separator: "\n")
            .lowercased()
    }

    var domain: Word {
        var word = Word(
            id: id,
            lemma: lemma,
            learningLanguage: learningLanguage,
            translationLanguage: translationLanguage,
            translation: translation,
            partOfSpeech: partOfSpeech,
            meanings: Self.decode(meaningsJSON),
            definition: definition,
            ipa: ipa,
            audioURL: audioURL,
            level: level,
            frequencyRank: frequencyRank,
            origin: origin,
            sourceID: sourceID,
            licenseID: licenseID,
            userNote: userNote,
            createdAt: createdAt
        )
        word.updatedAt = updatedAt
        return word
    }

    private static func encode(_ meanings: [WordMeaning]) -> String {
        guard !meanings.isEmpty, let data = try? JSONEncoder().encode(meanings) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode(_ json: String) -> [WordMeaning] {
        guard !json.isEmpty else { return [] }
        return (try? JSONDecoder().decode([WordMeaning].self, from: Data(json.utf8))) ?? []
    }
}

extension ExampleSentenceEntity {
    func apply(_ example: ExampleSentence) {
        id = example.id
        wordID = example.wordID
        sentence = example.sentence
        translation = example.translation
        sourceID = example.sourceID
        licenseID = example.licenseID
        isUserCreated = example.isUserCreated
        createdAt = example.createdAt
        searchText = example.sentence.lowercased()
    }

    var domain: ExampleSentence {
        ExampleSentence(
            id: id,
            wordID: wordID,
            sentence: sentence,
            translation: translation,
            sourceID: sourceID,
            licenseID: licenseID,
            isUserCreated: isUserCreated,
            createdAt: createdAt
        )
    }
}

extension WordProgressEntity {
    func apply(_ progress: WordProgress) {
        id = progress.id
        wordID = progress.wordID
        status = progress.status
        repetitionCount = progress.repetitionCount
        correctCount = progress.correctCount
        incorrectCount = progress.incorrectCount
        difficulty = progress.difficulty
        stability = progress.stability
        intervalDays = progress.intervalDays
        lastReviewedAt = progress.lastReviewedAt
        nextReviewAt = progress.nextReviewAt
        introducedAt = progress.introducedAt
        suspendedFromStatus = progress.suspendedFromStatus
        createdAt = progress.createdAt
        updatedAt = progress.updatedAt
        statusRaw = progress.status.rawValue
        isSchedulable = LearningRules.isSchedulable(progress.status)
        isMastered = progress.status == .remembered || progress.status == .known
        dueAt = progress.nextReviewAt ?? Date.distantFuture
        introducedSortKey = progress.introducedAt ?? Date.distantPast
    }

    var domain: WordProgress {
        var progress = WordProgress(id: id, wordID: wordID, createdAt: createdAt)
        progress.status = status
        progress.repetitionCount = repetitionCount
        progress.correctCount = correctCount
        progress.incorrectCount = incorrectCount
        progress.difficulty = difficulty
        progress.stability = stability
        progress.intervalDays = intervalDays
        progress.lastReviewedAt = lastReviewedAt
        progress.nextReviewAt = nextReviewAt
        progress.introducedAt = introducedAt
        progress.suspendedFromStatus = suspendedFromStatus
        progress.updatedAt = updatedAt
        return progress
    }
}

extension ReviewRecordEntity {
    func apply(_ record: ReviewRecord) {
        id = record.id
        wordID = record.wordID
        reviewedAt = record.reviewedAt
        rating = record.rating
        previousIntervalDays = record.previousIntervalDays
        scheduledIntervalDays = record.scheduledIntervalDays
        responseDurationMilliseconds = record.responseDurationMilliseconds
        sessionID = record.sessionID
    }

    var domain: ReviewRecord {
        ReviewRecord(
            id: id,
            wordID: wordID,
            reviewedAt: reviewedAt,
            rating: rating,
            previousIntervalDays: previousIntervalDays,
            scheduledIntervalDays: scheduledIntervalDays,
            responseDurationMilliseconds: responseDurationMilliseconds,
            sessionID: sessionID
        )
    }
}

extension DailyWordAssignmentEntity {
    func apply(_ assignment: DailyWordAssignment) {
        id = assignment.id
        localDayID = assignment.localDayID
        wordID = assignment.wordID
        assignedAt = assignment.assignedAt
        timeZoneIdentifier = assignment.timeZoneIdentifier
    }

    var domain: DailyWordAssignment {
        DailyWordAssignment(
            id: id,
            localDayID: localDayID,
            wordID: wordID,
            assignedAt: assignedAt,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}

extension UserSettingsEntity {
    func apply(_ settings: UserSettings) {
        learningLanguage = settings.learningLanguage
        translationLanguage = settings.translationLanguage
        proficiencyLevel = settings.proficiencyLevel
        newWordsPerDay = settings.newWordsPerDay
        dailyReminderEnabled = settings.dailyReminderEnabled
        dailyReminderMinutes = settings.dailyReminderMinutes
        notifyWordOfDay = settings.notifyWordOfDay
        notifyReviews = settings.notifyReviews
        notifyStreak = settings.notifyStreak
        notificationWeekdays = settings.notificationWeekdays
        maxNotificationsPerDay = settings.maxNotificationsPerDay
        preferredTheme = settings.preferredTheme
        soundEnabled = settings.soundEnabled
        phrasesInToday = settings.phrasesInToday
        onboardingCompleted = settings.onboardingCompleted
    }

    var domain: UserSettings {
        UserSettings(
            learningLanguage: learningLanguage,
            translationLanguage: translationLanguage,
            proficiencyLevel: proficiencyLevel,
            newWordsPerDay: newWordsPerDay,
            dailyReminderEnabled: dailyReminderEnabled,
            dailyReminderMinutes: dailyReminderMinutes,
            notifyWordOfDay: notifyWordOfDay,
            notifyReviews: notifyReviews,
            notifyStreak: notifyStreak,
            notificationWeekdays: notificationWeekdays,
            maxNotificationsPerDay: maxNotificationsPerDay,
            preferredTheme: preferredTheme,
            soundEnabled: soundEnabled,
            phrasesInToday: phrasesInToday,
            onboardingCompleted: onboardingCompleted
        )
    }
}
