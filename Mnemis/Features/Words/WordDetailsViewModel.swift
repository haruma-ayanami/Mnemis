import Foundation
import Observation

/// Одно слово: статус, примеры, заметка и ручное дополнение из источников.
@Observable
@MainActor
final class WordDetailsViewModel {
    private(set) var word: Word
    private(set) var progress: WordProgress?
    private(set) var examples: [ExampleSentence] = []
    private(set) var message: String?
    private(set) var isEnriching = false
    private(set) var errorMessage: String?
    /// Сколько новых слов начато сегодня и дневной лимит: для подсказки «6 / 5 new».
    private(set) var newToday = 0
    private(set) var newLimit = 5

    private let container: AppContainer
    private let onChange: () -> Void

    init(word: Word, container: AppContainer, onChange: @escaping () -> Void) {
        self.word = word
        self.container = container
        self.onChange = onChange
        reload()
    }

    var status: LearningStatus { progress?.status ?? .new }

    /// Показывать выбор «Today / Practice / Later»: слово или идиома не начаты либо размещены вручную и не повторялись.
    var canPlace: Bool { LearningRules.canPlace(progress) }

    var placement: StudyPlacement? { LearningRules.placement(of: progress, now: container.clock.now) }

    func reload() {
        do {
            word = try container.words.word(id: word.id) ?? word
            progress = try container.progress.progress(forWordID: word.id)
            examples = try container.words.examples(forWordID: word.id)
            let now = container.clock.now
            newToday = try container.progress.countIntroduced(since: LocalDay.start(of: now, calendar: container.clock.calendar))
            newLimit = try container.settings.load().newWordsPerDay
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markKnown() { perform { try container.wordStatus.markKnown(wordID: word.id) } }
    func restoreToLearning() { perform { try container.wordStatus.restoreToLearning(wordID: word.id) } }
    func suspend() { perform { try container.wordStatus.suspend(wordID: word.id) } }
    func resume() { perform { try container.wordStatus.resume(wordID: word.id) } }
    /// Выбор плитки: повторное нажатие на выбранную отменяет размещение.
    func togglePlacement(_ target: StudyPlacement) {
        let remove = placement == target
        perform {
            if remove {
                try container.wordStatus.removeFromStudy(wordID: word.id)
            } else {
                try container.wordStatus.place(wordID: word.id, as: target)
            }
            // Today и Learn пересчитывают счётчики и очередь.
            container.router.requestRefresh()
        }
    }

    func setStatus(_ status: LearningStatus) { perform { try container.wordStatus.setStatus(wordID: word.id, to: status) } }

    /// Удаляет слово или идиому пользователя. Возвращает `true`, если удаление прошло.
    func delete() -> Bool {
        do {
            try container.wordEditor.delete(word)
            onChange()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addExample(_ sentence: String) {
        perform { try container.wordEditor.addExample(wordID: word.id, sentence: sentence) }
    }

    func saveNote(_ note: String) {
        var updated = word
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.userNote = trimmed.isEmpty ? nil : trimmed
        perform { try container.wordEditor.update(updated) }
    }

    /// Сохраняет правку значений. Пустое значение удаляется; первое оставшееся становится основным переводом.
    func update(meanings: [WordMeaning], definition: String, ipa: String, level: String?) {
        var updated = word
        let kept = meanings
            .map { WordMeaning(partOfSpeech: $0.partOfSpeech, translation: $0.translation.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.translation.isEmpty }
        updated.translation = kept.first?.translation ?? ""
        if let first = kept.first, !first.partOfSpeech.isEmpty { updated.partOfSpeech = first.partOfSpeech }
        // Одно значение хранится как обычный перевод, без списка.
        updated.meanings = kept.count > 1 ? kept : []
        let newDefinition = definition.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let newIPA = ipa.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        // Поле, которое пользователь изменил, перестаёт быть «auto» и словарь его не перезапишет.
        if newDefinition != word.definition { updated.editedFields.insert(Word.editedDefinition) }
        if newIPA != word.ipa { updated.editedFields.insert(Word.editedIPA) }
        updated.definition = newDefinition
        updated.ipa = newIPA
        updated.level = level
        perform { try container.wordEditor.update(updated) }
    }

    /// Дополняет слово из источников. Без сети просто сообщает об этом.
    func enrich() async {
        isEnriching = true
        defer { isEnriching = false }
        do {
            switch try await container.wordEnrichment.enrich(wordID: word.id) {
            case .updated(let count): message = "Added \(count) field(s) from sources."
            case .nothingToAdd: message = "Nothing new to add."
            case .notFound: message = "No entry found for this word."
            case .unavailable: message = "Sources are unavailable. Your word is saved; try again later."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        reload()
        onChange()
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
            reload()
            onChange()
        } catch WordEditorError.emptyLemma {
            errorMessage = "The word cannot be empty."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
