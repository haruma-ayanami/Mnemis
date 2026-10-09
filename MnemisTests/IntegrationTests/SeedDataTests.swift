import Testing
import Foundation
@testable import Mnemis

/// Встроенный словарь из бандла приложения: читается, импортируется один раз и содержит лицензии.
@MainActor
struct SeedDataTests {
    let clock = TestClock()

    @Test func bundledSeedDecodesAndHasLicenses() throws {
        let contents = try SeedBundle.load(bundle: .main)

        #expect(contents.words.words.count >= 1)
        for word in contents.words.words {
            let source = try #require(contents.manifest.source(id: contents.words.sourceID))
            #expect(contents.manifest.license(id: source.licenseID) != nil, "No license for \(word.lemma)")
        }
    }

    @Test func importIsIdempotent() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let contents = try SeedBundle.load(bundle: .main)
        let importer = SeedDataImporter(words: container.words, persistence: container.persistence)

        let first = try importer.importWords(contents.words, manifest: contents.manifest, now: clock.now)
        let second = try importer.importWords(contents.words, manifest: contents.manifest, now: clock.now)

        #expect(first == contents.words.words.count)
        #expect(second == 0)
        #expect(try container.words.allWords().count == contents.words.words.count)
    }

    @Test func importedWordsKeepSourceAndLicense() throws {
        let container = try AppContainer.inMemory(clock: clock)
        let contents = try SeedBundle.load(bundle: .main)
        try SeedDataImporter(words: container.words, persistence: container.persistence)
            .importWords(contents.words, manifest: contents.manifest, now: clock.now)

        for word in try container.words.allWords() {
            #expect(word.origin == .builtin)
            #expect(word.sourceID == contents.words.sourceID)
            #expect(word.licenseID != nil)
        }
    }
}
