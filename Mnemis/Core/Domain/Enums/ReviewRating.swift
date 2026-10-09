import Foundation

/// Оценка после показа карточки (ABOUT.md, раздел 7).
enum ReviewRating: String, Codable, CaseIterable, Sendable {
    case again
    case hard
    case good
    case easy

    /// Слово вспомнено, хотя бы с усилием. Для точности ответов.
    var isCorrect: Bool { self != .again }

    /// Оценка, после которой слово уходит в обычное повторение.
    var isPassing: Bool { self == .good || self == .easy }
}
