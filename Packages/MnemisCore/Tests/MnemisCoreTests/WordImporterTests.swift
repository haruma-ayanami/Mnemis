import Testing
import Foundation
import SwiftData
@testable import MnemisCore

@MainActor
struct WordImporterTests {
    private let seed = """
    {
      "source": "test",
      "license": "test-license",
      "words": [
        { "word": "accomplish", "translation": "выполнять", "partOfSpeech": "verb", "definition": "to finish", "level": "B1" },
        { "word": "Achieve", "translation": "достигать", "partOfSpeech": "verb", "definition": "to reach", "level": "A2" }
      ]
    }
    """
    /// Контейнер держим в наборе: `mainContext` недействителен после освобождения контейнера.
    private let container: ModelContainer

    init() throws {
        container = try MnemisStore.makeContainer(inMemory: true)
    }

    @Test func importsWordsWithSourceAndLicense() throws {
        let context = container.mainContext

        let added = try WordImporter().importSeed(data: Data(seed.utf8), into: context)
        let words = try context.fetch(FetchDescriptor<Word>())

        #expect(added == 2)
        #expect(words.allSatisfy { $0.origin == .builtin })
        #expect(words.allSatisfy { $0.license == "test-license" })
    }

    @Test func reimportDoesNotDuplicateWords() throws {
        let context = container.mainContext
        let importer = WordImporter()

        try importer.importSeed(data: Data(seed.utf8), into: context)
        let secondRun = try importer.importSeed(data: Data(seed.utf8), into: context)

        #expect(secondRun == 0)
        #expect(try context.fetch(FetchDescriptor<Word>()).count == 2)
    }
}
