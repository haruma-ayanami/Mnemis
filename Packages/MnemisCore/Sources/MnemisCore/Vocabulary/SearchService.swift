import Foundation

/// Локальный поиск без сети (ABOUT.md, раздел 14).
/// Ищет по слову, переводу, определению, собственным примерам и заметкам.
public enum SearchService {
    /// - Parameters:
    ///   - query: строка поиска. Пустая строка возвращает все слова.
    ///   - words: слова для поиска.
    ///   - userTexts: собственные примеры и заметки по `Word.id`.
    /// - Returns: совпадения. Сначала слова, начинающиеся с запроса, затем содержащие его.
    public static func search(_ query: String, in words: [Word], userTexts: [UUID: [String]] = [:]) -> [Word] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return words }

        let scored = words.compactMap { word -> (word: Word, score: Int)? in
            let lemma = word.lemma.lowercased()
            if lemma.hasPrefix(needle) { return (word, 0) }
            if lemma.contains(needle) { return (word, 1) }

            let fields = [word.translation, word.definition] + (userTexts[word.id] ?? [])
            if fields.contains(where: { $0.lowercased().contains(needle) }) {
                return (word, 2)
            }
            return nil
        }

        return scored
            .sorted { ($0.score, $0.word.lemma) < ($1.score, $1.word.lemma) }
            .map(\.word)
    }
}
