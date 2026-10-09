import Foundation
import SwiftData

/// Импорт встроенного словаря из JSON (ABOUT.md, раздел 13).
/// Данные хранятся отдельно от Swift-кода. Для каждой записи сохраняются источник и лицензия.
public struct WordImporter {
    struct Seed: Decodable {
        let source: String
        let license: String
        let words: [SeedWord]
    }

    struct SeedWord: Decodable {
        let word: String
        let translation: String
        let partOfSpeech: String
        let definition: String
        let level: String?
        let frequency: Int?
        let examples: [String]?
    }

    public init() {}

    /// Добавляет слова, которых ещё нет в базе. Повторный импорт ничего не дублирует.
    /// - Returns: количество добавленных слов.
    @discardableResult
    public func importSeed(data: Data, into context: ModelContext) throws -> Int {
        let seed = try JSONDecoder().decode(Seed.self, from: data)
        var known = Set(try context.fetch(FetchDescriptor<Word>()).map { $0.lemma.lowercased() })
        var added = 0

        for item in seed.words where !known.contains(item.word.lowercased()) {
            context.insert(Word(
                lemma: item.word,
                translation: item.translation,
                definition: item.definition,
                partOfSpeech: item.partOfSpeech,
                examples: item.examples ?? [],
                level: item.level,
                frequency: item.frequency,
                origin: .builtin,
                source: seed.source,
                license: seed.license
            ))
            known.insert(item.word.lowercased())
            added += 1
        }
        return added
    }

    @discardableResult
    public func importSeed(from url: URL, into context: ModelContext) throws -> Int {
        try importSeed(data: Data(contentsOf: url), into: context)
    }
}
