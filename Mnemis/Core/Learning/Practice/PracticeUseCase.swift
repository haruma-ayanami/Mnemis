import Foundation

/// Что есть для упражнений: сколько слов учит пользователь, сколько закреплено и сколько знакомо.
struct PracticePlan: Equatable, Sendable {
    let learning: Int
    let reviewing: Int
    let remembered: Int
    let known: Int

    /// Слова, по которым идут основные вопросы: учит и повторяет.
    var active: Int { learning + reviewing }
    var isEmpty: Bool { active + remembered == 0 }
}

/// Упражнения на основе прогресса: учим и повторяем — основные вопросы, закреплённые — если не хватает,
/// знакомые — не больше одного вопроса за сессию. Прогресс SRS упражнения не меняют.
@MainActor
struct PracticeUseCase {
    let words: WordRepository
    let progress: ProgressRepository

    /// Размер сессии по умолчанию: столько вопросов за один заход.
    static let sessionSize = 12

    func plan() throws -> PracticePlan {
        PracticePlan(
            learning: try progress.count(status: .learning),
            reviewing: try progress.count(status: .reviewing),
            remembered: try progress.count(status: .remembered),
            known: try progress.count(status: .known)
        )
    }

    /// Вопросы для одной сессии. Порядок и варианты детерминированы по `seed`.
    func questions(count: Int = sessionSize, seed: UInt64) throws -> [PracticeQuestion] {
        var random = SeededRandom(seed: seed)
        let primary = try wordsWithStatus(.learning) + wordsWithStatus(.reviewing)
        let secondary = try wordsWithStatus(.remembered)
        let bonus = try wordsWithStatus(.known)

        let pool = try words.sample(limit: 60, using: &random) + words.idioms()
        var examples: [UUID: [String]] = [:]
        for word in (primary + secondary).prefix(count * 2) {
            examples[word.id] = try words.examples(forWordID: word.id).map(\.sentence)
        }

        return PracticeBuilder.questions(
            primary: primary,
            secondary: secondary,
            bonus: bonus,
            pool: pool,
            examples: examples,
            count: count,
            seed: seed
        )
    }

    /// Слова выбранного статуса. Знакомых может быть много, поэтому берём случайную часть.
    private func wordsWithStatus(_ status: LearningStatus) throws -> [Word] {
        let ids = try progress.wordIDs(status: status)
        return try words.words(ids: Array(ids.prefix(400)))
    }
}
