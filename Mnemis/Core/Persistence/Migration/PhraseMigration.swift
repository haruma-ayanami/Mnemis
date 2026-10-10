import Foundation
import SwiftData

/// Однократный перенос личных идиом из прежней таблицы `PhraseEntity` в слова с частью речи `idiom`.
/// После переноса таблица пустеет: прогресс, статусы и повторения у идиом теперь те же, что у слов.
@MainActor
enum PhraseMigration {
    static let defaultsKey = "mnemis.phrasesMigratedToWords"

    static func run(
        persistence: PersistenceController,
        words: WordRepository,
        wordStatus: WordStatusUseCase,
        defaults: UserDefaults = .standard
    ) throws {
        guard !defaults.bool(forKey: defaultsKey) else { return }
        let context = persistence.context
        let legacy = try context.fetch(FetchDescriptor<PhraseEntity>())

        var known: [UUID] = []
        for item in legacy {
            let word = Word(
                id: item.id,
                lemma: item.text,
                translation: item.meaning,
                partOfSpeech: Word.idiomPartOfSpeech,
                origin: .user,
                sourceID: "user",
                userNote: item.note,
                createdAt: item.createdAt
            )
            words.insert(word)
            if let example = item.example, !example.isEmpty {
                words.insert(ExampleSentence(wordID: word.id, sentence: example, isUserCreated: true, createdAt: item.createdAt))
            }
            let extra = item.userExamplesJSON.isEmpty
                ? []
                : (try? JSONDecoder().decode([String].self, from: Data(item.userExamplesJSON.utf8))) ?? []
            for sentence in extra {
                words.insert(ExampleSentence(wordID: word.id, sentence: sentence, isUserCreated: true, createdAt: item.createdAt))
            }
            if item.isKnown { known.append(word.id) }
            context.delete(item)
        }
        try persistence.save()
        for id in known {
            try wordStatus.markKnown(wordID: id)
        }
        defaults.set(true, forKey: defaultsKey)
    }
}
