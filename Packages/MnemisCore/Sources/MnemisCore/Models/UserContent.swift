import Foundation
import SwiftData

/// Собственный пример использования слова (ABOUT.md, раздел 10).
@Model
public final class UserExample {
    public var id: UUID
    public var wordID: UUID
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), wordID: UUID, text: String, createdAt: Date = .now) {
        self.id = id
        self.wordID = wordID
        self.text = text
        self.createdAt = createdAt
    }
}

/// Личная заметка к слову (ABOUT.md, раздел 4).
@Model
public final class UserNote {
    public var id: UUID
    public var wordID: UUID
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), wordID: UUID, text: String, createdAt: Date = .now) {
        self.id = id
        self.wordID = wordID
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
