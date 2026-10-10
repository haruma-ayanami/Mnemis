import Foundation
import Observation

/// Сессия упражнений: вопросы, выбор варианта, результат. Прогресс SRS не меняет.
@Observable
@MainActor
final class PracticeViewModel {
    private(set) var plan: PracticePlan?
    private(set) var questions: [PracticeQuestion] = []
    private(set) var index = 0
    /// Выбранный вариант текущего вопроса; пока `nil`, вопрос открыт.
    private(set) var selected: PracticeOption?
    private(set) var results: [Bool] = []
    private(set) var isFinished = false
    private(set) var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var current: PracticeQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var correctCount: Int { results.filter { $0 }.count }

    func loadPlan() {
        do {
            plan = try container.practice.plan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Новая сессия. Варианты зависят от времени запуска: каждый заход отличается.
    func start() {
        do {
            questions = try container.practice.questions(seed: UInt64(Date.now.timeIntervalSince1970 * 1000))
            index = 0
            selected = nil
            results = []
            isFinished = questions.isEmpty
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func choose(_ option: PracticeOption) {
        guard selected == nil, let question = current else { return }
        selected = option
        results.append(question.isCorrect(option))
    }

    func next() {
        selected = nil
        if index + 1 < questions.count {
            index += 1
        } else {
            isFinished = true
        }
    }
}
