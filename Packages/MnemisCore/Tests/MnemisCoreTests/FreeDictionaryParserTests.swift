import Testing
import Foundation
@testable import MnemisCore

struct FreeDictionaryParserTests {
    private let fixture = """
    [
      {
        "word": "accomplish",
        "phonetic": "/əˈkʌmplɪʃ/",
        "phonetics": [
          { "text": "/əˈkʌmplɪʃ/", "audio": "https://example.com/accomplish.mp3" }
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

    @Test func parsesWordPronunciationAndMeanings() throws {
        let entry = try #require(try FreeDictionaryParser.parse(Data(fixture.utf8)))

        #expect(entry.lemma == "accomplish")
        #expect(entry.ipa == "/əˈkʌmplɪʃ/")
        #expect(entry.audioURL?.absoluteString == "https://example.com/accomplish.mp3")
        #expect(entry.meanings.count == 1)
        #expect(entry.meanings[0].partOfSpeech == "verb")
        #expect(entry.meanings[0].example == "She accomplished her goal.")
        #expect(entry.meanings[0].synonyms.sorted() == ["achieve", "complete"])
        #expect(entry.meanings[0].antonyms == ["fail"])
    }

    @Test func emptyArrayMeansNoEntry() throws {
        #expect(try FreeDictionaryParser.parse(Data("[]".utf8)) == nil)
    }

    @Test func mapsEntryToCachedWord() throws {
        let entry = try #require(try FreeDictionaryParser.parse(Data(fixture.utf8)))
        let word = Word.make(from: entry, source: "dictionaryapi.dev", license: "check provider terms")

        #expect(word.origin == .api)
        #expect(word.lemma == "accomplish")
        #expect(word.definition == "to successfully complete something")
        #expect(word.examples == ["She accomplished her goal."])
        #expect(word.license == "check provider terms")
    }
}
