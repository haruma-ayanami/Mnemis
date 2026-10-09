import Foundation

/// Статус слова в процессе обучения (ABOUT.md, раздел 6).
public enum LearningStatus: String, Codable, CaseIterable, Sendable {
    case new
    case learning
    case reviewing
    case remembered
    case known
    case suspended
}

/// Оценка после показа карточки (ABOUT.md, раздел 7).
public enum ReviewRating: String, Codable, CaseIterable, Sendable {
    case again
    case hard
    case good
    case easy

    /// Слово вспомнено (хотя бы с усилием). Используется для счётчиков точности.
    public var isCorrect: Bool { self != .again }

    /// Оценка, после которой слово переходит к повторению в обычном режиме.
    public var isPassing: Bool { self == .good || self == .easy }
}

/// Откуда взято слово.
public enum WordOrigin: String, Codable, Sendable {
    /// Встроенный словарь приложения (JSON в ресурсах приложения).
    case builtin
    /// Добавлено пользователем вручную.
    case user
    /// Кэш ответа внешнего API.
    case api
}
