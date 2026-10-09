import Foundation

/// Статус слова в процессе обучения (ARCHITECTURE.md, раздел 4).
enum LearningStatus: String, Codable, CaseIterable, Sendable {
    /// Слово ещё не изучалось.
    case new
    /// Начальное изучение, короткие интервалы.
    case learning
    /// Обычное интервальное повторение.
    case reviewing
    /// Интервал достиг порога надёжного запоминания.
    case remembered
    /// Пользователь вручную отметил слово как известное.
    case known
    /// Временно исключено из очередей. Прежний статус хранится в `WordProgress.suspendedFromStatus`.
    case suspended
}
