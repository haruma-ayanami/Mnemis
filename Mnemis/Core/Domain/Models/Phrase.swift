import Foundation

/// Идиома, которую пользователь добавил в словарь (ABOUT.md, раздел 9.1).
/// Значение можно подставить из открытого словаря идиом или написать самому.
struct Phrase: Identifiable, Equatable, Sendable {
    let id: UUID
    /// Сама идиома, например `break the ice`.
    var text: String
    /// Значение или перевод.
    var meaning: String
    /// Пример из словаря или первый пример пользователя.
    var example: String?
    /// Свои примеры пользователя, кроме `example`.
    var userExamples: [String]
    /// Личная заметка.
    var note: String?
    /// «Я знаю эту идиому»: такие идиомы реже попадают в идиому дня.
    var isKnown: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        meaning: String,
        example: String? = nil,
        userExamples: [String] = [],
        note: String? = nil,
        isKnown: Bool = false,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.meaning = meaning
        self.example = example
        self.userExamples = userExamples
        self.note = note
        self.isKnown = isKnown
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
