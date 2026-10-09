import Foundation

/// Локальный поиск без сети. Реализация скрыта, поэтому её можно заменить, не трогая `WordsView`
/// (ARCHITECTURE.md, раздел 10).
enum SearchService {
    /// - Parameters:
    ///   - query: строка поиска. Пустая строка возвращает все слова.
    ///   - words: слова для поиска.
    ///   - userTexts: пользовательские примеры и заметки по `Word.id`.
    /// - Returns: сначала слова, которые начинаются с запроса, затем содержащие его.
    static func search(_ query: String, in words: [Word], userTexts: [UUID: [String]] = [:]) -> [Word] {
        let needle = TextNormalizer.normalize(query)
        guard !needle.isEmpty else { return words }

        let scored = words.compactMap { word -> (word: Word, score: Int)? in
            let lemma = word.normalizedLemma
            if lemma.hasPrefix(needle) { return (word, 0) }
            if lemma.contains(needle) { return (word, 1) }

            let fields = [word.translation, word.definition ?? "", word.userNote ?? ""] + (userTexts[word.id] ?? [])
            let matches = fields.contains { TextNormalizer.normalize($0).contains(needle) }
            return matches ? (word, 2) : nil
        }

        return scored
            .sorted { ($0.score, $0.word.lemma) < ($1.score, $1.word.lemma) }
            .map(\.word)
    }
}
