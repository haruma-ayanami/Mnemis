import Foundation

/// Откуда появилась запись словаря.
enum WordOrigin: String, Codable, Sendable {
    /// Встроенный словарь из `SeedData`.
    case builtin
    /// Добавлено пользователем. Пользовательский контент никогда не перезаписывается API.
    case user
    /// Кэш ответа внешнего источника.
    case api
}
