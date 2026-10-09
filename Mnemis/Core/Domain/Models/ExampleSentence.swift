import Foundation

/// Пример употребления слова. Пользовательские примеры хранятся отдельно от примеров из источников,
/// чтобы обновление данных из API их не затирало (ARCHITECTURE.md, раздел 3).
struct ExampleSentence: Identifiable, Equatable, Sendable {
    let id: UUID
    var wordID: UUID
    var sentence: String
    var translation: String?
    var sourceID: String?
    var licenseID: String?
    var isUserCreated: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        wordID: UUID,
        sentence: String,
        translation: String? = nil,
        sourceID: String? = nil,
        licenseID: String? = nil,
        isUserCreated: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.wordID = wordID
        self.sentence = sentence
        self.translation = translation
        self.sourceID = sourceID
        self.licenseID = licenseID
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
    }
}
