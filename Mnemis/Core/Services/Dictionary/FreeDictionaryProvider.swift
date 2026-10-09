import Foundation

/// Free Dictionary API (dictionaryapi.dev). Только обогащение: основное обучение работает без сети.
struct FreeDictionaryProvider: DictionaryProvider {
    static let baseURL = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/")!
    /// Ключ лицензии в `seed-manifest.json`. Текст лицензии нужно проверить перед релизом.
    static let licenseID = "dictionaryapi-dev"

    let sourceID = "dictionaryapi.dev"
    let client: APIClient
    let baseURL: URL

    init(client: APIClient = APIClient(), baseURL: URL = FreeDictionaryProvider.baseURL) {
        self.client = client
        self.baseURL = baseURL
    }

    func entry(for lemma: String) async throws -> DictionaryEntry? {
        let term = TextNormalizer.normalize(lemma)
        guard !term.isEmpty,
              let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURL.absoluteString + encoded) else {
            return nil
        }

        do {
            let data = try await client.data(from: url)
            return try FreeDictionaryParser.parse(data, sourceID: sourceID, licenseID: Self.licenseID)
        } catch APIError.notFound {
            return nil
        }
    }
}

/// Разбор ответа API. Отделён от сети, поэтому покрывается тестами на фикстурах.
/// Неполный ответ допустим: отсутствующие поля становятся `nil`.
enum FreeDictionaryParser {
    static func parse(_ data: Data, sourceID: String, licenseID: String) throws -> DictionaryEntry? {
        let items = try JSONDecoder().decode([Response].self, from: data)
        guard let item = items.first else { return nil }

        let meanings = item.meanings ?? []
        let firstMeaning = meanings.first
        let firstDefinition = firstMeaning?.definitions?.first

        let ipa = item.phonetic ?? item.phonetics?.compactMap(\.text).first { !$0.isEmpty }
        let audioString = item.phonetics?.compactMap(\.audio).first { !$0.isEmpty }
        let examples = meanings
            .flatMap { $0.definitions ?? [] }
            .compactMap(\.example)
            .filter { !$0.isEmpty }

        return DictionaryEntry(
            lemma: item.word,
            ipa: ipa,
            audioURL: audioString.flatMap { URL(string: $0) },
            partOfSpeech: firstMeaning?.partOfSpeech,
            definition: firstDefinition?.definition,
            examples: examples,
            sourceID: sourceID,
            licenseID: licenseID
        )
    }

    private struct Response: Decodable {
        let word: String
        let phonetic: String?
        let phonetics: [Phonetic]?
        let meanings: [Meaning]?
    }

    private struct Phonetic: Decodable {
        let text: String?
        let audio: String?
    }

    private struct Meaning: Decodable {
        let partOfSpeech: String?
        let definitions: [Definition]?
    }

    private struct Definition: Decodable {
        let definition: String?
        let example: String?
    }
}
