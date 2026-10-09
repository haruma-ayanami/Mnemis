import Foundation

/// Формат `SeedData/words-en-ru.json`: встроенный словарь, отдельно от Swift-кода.
struct SeedWords: Decodable, Sendable {
    let sourceID: String
    /// Версия данных. Когда она растёт, встроенные слова у уже установленного приложения обновляются.
    let version: Int?
    let words: [SeedWord]
}

struct SeedWord: Decodable, Sendable {
    let lemma: String
    let translation: String
    let partOfSpeech: String?
    /// Значения по частям речи, если их несколько.
    let meanings: [WordMeaning]?
    let definition: String?
    let ipa: String?
    let level: String?
    let frequencyRank: Int?
    let examples: [String]?
}

/// Формат `SeedData/seed-manifest.json`: источники и лицензии. Нужны для экрана «Источники и лицензии».
struct SeedManifest: Decodable, Sendable {
    struct Source: Decodable, Sendable {
        let id: String
        let name: String
        let url: String?
        let licenseID: String
    }

    struct License: Decodable, Sendable {
        let id: String
        let name: String
        let text: String
    }

    /// Версия встроенного словаря (`words-en-ru.json`). Читается без разбора всего словаря.
    let seedVersion: Int?
    let sources: [Source]
    let licenses: [License]

    func source(id: String) -> Source? {
        sources.first { $0.id == id }
    }

    func license(id: String) -> License? {
        licenses.first { $0.id == id }
    }
}

/// Загрузка данных из бандла приложения.
enum SeedBundle {
    struct Contents {
        let words: SeedWords
        let manifest: SeedManifest
    }

    static func load(bundle: Bundle = .main) throws -> Contents {
        let wordsData = try data(named: "words-en-ru", bundle: bundle)
        let manifestData = try data(named: "seed-manifest", bundle: bundle)
        return Contents(
            words: try JSONDecoder().decode(SeedWords.self, from: wordsData),
            manifest: try JSONDecoder().decode(SeedManifest.self, from: manifestData)
        )
    }

    /// Только манифест: экран настроек не должен разбирать весь словарь ради списка источников.
    static func loadManifest(bundle: Bundle = .main) throws -> SeedManifest {
        try JSONDecoder().decode(SeedManifest.self, from: data(named: "seed-manifest", bundle: bundle))
    }

    /// Ресурс может лежать в подпапке `SeedData` или в корне бандла, поэтому ищем в обоих местах.
    private static func data(named name: String, bundle: Bundle) throws -> Data {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "SeedData")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: url)
    }
}
