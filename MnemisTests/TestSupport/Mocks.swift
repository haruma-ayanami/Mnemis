import Foundation
@testable import Mnemis

/// Заглушка источника: возвращает заданный ответ или ошибку.
struct StubDictionaryProvider: DictionaryProvider {
    let sourceID: String
    var entry: DictionaryEntry?
    var error: (any Error)?

    func entry(for lemma: String) async throws -> DictionaryEntry? {
        if let error { throw error }
        return entry
    }
}

enum Fixtures {
    static func entry(
        lemma: String = "accomplish",
        ipa: String? = "/əˈkʌmplɪʃ/",
        definition: String? = "to successfully complete something",
        examples: [String] = ["She accomplished her goal."]
    ) -> DictionaryEntry {
        DictionaryEntry(
            lemma: lemma,
            ipa: ipa,
            audioURL: nil,
            partOfSpeech: "verb",
            definition: definition,
            examples: examples,
            sourceID: "stub",
            licenseID: "stub-license"
        )
    }

    /// Ответ Free Dictionary API в той форме, которую мы получаем.
    static let freeDictionaryAccomplish = """
    [
      {
        "word": "accomplish",
        "phonetic": "/əˈkʌmplɪʃ/",
        "phonetics": [
          { "text": "/əˈkʌmplɪʃ/", "audio": "https://example.test/accomplish.mp3" }
        ],
        "meanings": [
          {
            "partOfSpeech": "verb",
            "definitions": [
              {
                "definition": "to successfully complete something",
                "example": "She accomplished her goal.",
                "synonyms": ["achieve"],
                "antonyms": []
              }
            ],
            "synonyms": ["complete"],
            "antonyms": ["fail"]
          }
        ]
      }
    ]
    """

    /// Неполный ответ: нет фонетики и значений. Должен разбираться без падения.
    static let freeDictionaryIncomplete = """
    [ { "word": "serendipity" } ]
    """
}
