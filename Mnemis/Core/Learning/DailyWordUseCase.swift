import Foundation

/// Слово дня (ARCHITECTURE.md, раздел 6). Выбирается один раз на локальный день и сохраняется.
@MainActor
struct DailyWordUseCase {
    let words: WordRepository
    let progress: ProgressRepository
    let dailyWords: DailyWordRepository
    let persistence: PersistenceController
    let clock: any Clock

    /// Возвращает уже назначенное слово дня или выбирает и сохраняет новое.
    func todaysWord(preferredLevel: String?) throws -> Word? {
        let dayID = LocalDay.id(for: clock.now, calendar: clock.calendar)

        if let assignment = try dailyWords.assignment(forDay: dayID),
           let word = try words.word(id: assignment.wordID) {
            return word
        }

        let candidates = try words.allWords()
        let progressAll = try progress.all()
        let previouslyAssigned = Set(try dailyWords.all().map(\.wordID))

        guard let chosen = DailyWordSelector.select(
            dayID: dayID,
            candidates: candidates,
            progress: progressAll,
            previouslyAssigned: previouslyAssigned,
            preferredLevel: preferredLevel
        ) else { return nil }

        dailyWords.insert(DailyWordAssignment(
            localDayID: dayID,
            wordID: chosen.id,
            assignedAt: clock.now,
            timeZoneIdentifier: clock.calendar.timeZone.identifier
        ))
        try persistence.save()
        return chosen
    }
}
