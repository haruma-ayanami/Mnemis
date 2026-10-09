import Foundation

// Маппинг личных идиом. Колонка `kindRaw` осталась от схемы с предложениями и всегда хранит "idiom".

extension PhraseEntity {
    func apply(_ phrase: Phrase) {
        id = phrase.id
        kindRaw = PhraseEntity.idiomKind
        text = phrase.text
        meaning = phrase.meaning
        example = phrase.example
        userExamplesJSON = phrase.userExamples.isEmpty ? "" : (try? String(decoding: JSONEncoder().encode(phrase.userExamples), as: UTF8.self)) ?? ""
        note = phrase.note
        isKnown = phrase.isKnown
        createdAt = phrase.createdAt
        updatedAt = phrase.updatedAt
        searchText = TextNormalizer.normalize(([phrase.text, phrase.meaning, phrase.example ?? "", phrase.note ?? ""] + phrase.userExamples).joined(separator: " "))
    }

    var domain: Phrase {
        Phrase(
            id: id,
            text: text,
            meaning: meaning,
            example: example,
            userExamples: userExamplesJSON.isEmpty ? [] : (try? JSONDecoder().decode([String].self, from: Data(userExamplesJSON.utf8))) ?? [],
            note: note,
            isKnown: isKnown,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
