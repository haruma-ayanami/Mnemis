import Foundation
import Testing
@testable import Mnemis

/// Упражнения: варианты, правильный ответ, пропуск в предложении и повторяемость по seed.
@MainActor
struct PracticeBuilderTests {
    private func word(_ lemma: String, _ meaning: String, idiom: Bool = false, pos: String = "noun") -> Word {
        Word(lemma: lemma, translation: meaning, partOfSpeech: idiom ? Word.idiomPartOfSpeech : pos, origin: .builtin, createdAt: Date(timeIntervalSince1970: 0))
    }

    private var pool: [Word] {
        [
            word("book", "книга, книжка"), word("table", "стол"), word("window", "окно"),
            word("river", "река"), word("garden", "сад"), word("bread", "хлеб"),
            word("break the ice", "разрядить обстановку", idiom: true),
            word("hit the books", "зубрить", idiom: true),
            word("spill the beans", "проболтаться", idiom: true),
        ]
    }

    @Test func everyQuestionHasFourOptionsAndExactlyOneCorrect() {
        let targets = [word("book", "книга, книжка"), word("river", "река")]
        let questions = PracticeBuilder.questions(primary: targets, pool: pool, examples: [:], count: 10, seed: 7)

        #expect(questions.count == 2)
        for question in questions {
            #expect(question.options.count == 4)
            #expect(question.options.filter { question.isCorrect($0) }.count == 1)
            #expect(Set(question.options.map(\.text)).count == 4)
        }
    }

    @Test func meaningQuestionShowsTheWordAndRussianOptions() throws {
        let target = word("book", "книга, книжка")
        var random = SeededRandom(seed: 1)
        let question = try #require(PracticeBuilder.make(for: target, pool: pool, examples: [], random: &random))

        if question.kind == .meaning {
            #expect(question.prompt == "book")
            #expect(question.options.contains { $0.text == "книга" })
        }
        #expect(question.kind != .context, "no example sentence was given")
    }

    @Test func contextQuestionBlanksTheWordInTheSentence() throws {
        let target = word("book", "книга, книжка")
        var random = SeededRandom(seed: 3)
        let question = try #require(PracticeBuilder.make(for: target, pool: pool, examples: ["I read a good Book on the train."], random: &random))

        if question.kind == .context {
            #expect(question.prompt == "I read a good ____ on the train.")
        }
    }

    @Test func distractorsPreferTheSameKind() {
        let idiom = word("break the ice", "разрядить обстановку", idiom: true)
        let extra = word("once in a blue moon", "очень редко", idiom: true)
        var random = SeededRandom(seed: 9)
        let distractors = PracticeBuilder.distractorWords(for: idiom, pool: pool + [extra], random: &random)

        #expect(distractors.count == 3)
        #expect(distractors.allSatisfy { $0.isIdiom })
    }

    @Test func sameSeedGivesTheSameSession() {
        let targets = [word("book", "книга"), word("river", "река"), word("garden", "сад")]
        let first = PracticeBuilder.questions(primary: targets, pool: pool, examples: [:], count: 3, seed: 42)
        let second = PracticeBuilder.questions(primary: targets, pool: pool, examples: [:], count: 3, seed: 42)

        #expect(first.map(\.wordID) == second.map(\.wordID))
        #expect(first.map { $0.options.map(\.text) } == second.map { $0.options.map(\.text) })
    }

    @Test func noQuestionWhenThereAreNotEnoughDistractors() {
        let target = word("book", "книга")
        let tiny = [target, word("table", "стол")]
        let questions = PracticeBuilder.questions(primary: [target], pool: tiny, examples: [:], count: 5, seed: 1)

        #expect(questions.isEmpty)
    }

    @Test func rememberedWordsFillInOnlyWhenActiveOnesRunOut() {
        let active = [word("book", "книга"), word("river", "река")]
        let remembered = [word("garden", "сад")]
        let questions = PracticeBuilder.questions(primary: active, secondary: remembered, pool: pool, examples: [:], count: 2, seed: 5)

        #expect(questions.count == 2)
        #expect(questions.allSatisfy { q in active.contains { $0.id == q.wordID } })
    }

    @Test func shortMeaningTakesTheFirstTranslation() {
        #expect(PracticeBuilder.shortMeaning(of: word("book", "книга, книжка")) == "книга")
        #expect(PracticeBuilder.shortMeaning(of: word("empty", "")) == nil)
    }
}
