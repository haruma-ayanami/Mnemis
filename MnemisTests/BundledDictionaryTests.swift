import Testing
import Foundation
import SwiftData
import MnemisCore
@testable import Mnemis

/// Тесты уровня приложения. Логика ядра тестируется в пакете MnemisCore (`swift test`).
@MainActor
struct BundledDictionaryTests {
    @Test func bundledWordsJSONIsValidAndImports() throws {
        let container = try MnemisStore.makeContainer(inMemory: true)
        let url = try #require(Bundle.main.url(forResource: "words", withExtension: "json"))

        let added = try WordImporter().importSeed(from: url, into: container.mainContext)

        #expect(added > 0)
    }
}
