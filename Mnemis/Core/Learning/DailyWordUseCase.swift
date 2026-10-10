import Foundation

/// Слово дня (ARCHITECTURE.md, раздел 6). Выбирается один раз на локальный день и сохраняется.
@MainActor
struct DailyWordUseCase {
    let words: WordRepository
    let progress: ProgressRepository
    let dailyWords: DailyWordRepository
    let persistence: PersistenceController
    let clock: any Clock

    /// Идиома дня: детерминированно по дню. Берём идиомы, которые пользователь ещё учит;
    /// если все отмечены «знаю» или отложены, выбираем из всех идиом.
    func idiomOfTheDay(dayID: String) throws -> Word? {
        let idioms = try words.idioms().sorted { $0.id.uuidString < $1.id.uuidString }
        guard !idioms.isEmpty else { return nil }
        let statuses = try progress.statuses(forWordIDs: idioms.map(\.id))
        let learning = idioms.filter { statuses[$0.id].map { $0 != .known && $0 != .suspended } ?? true }
        let pool = learning.isEmpty ? idioms : learning
        return pool[Int(DailyWordSelector.fnv1a(dayID) % UInt64(pool.count))]
    }

    /// Возвращает уже назначенное слово дня или выбирает и сохраняет новое.
    func todaysWord(preferredLevel: String?) throws -> Word? {
        let dayID = LocalDay.id(for: clock.now, calendar: clock.calendar)

        if let assignment = try dailyWords.assignment(forDay: dayID),
           let word = try words.word(id: assignment.wordID) {
            return word
        }

        // Слово дня — только слово: идиомы показываются отдельно, как идиома дня.
        let candidates = try words.allWords().filter { !$0.isIdiom }
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
