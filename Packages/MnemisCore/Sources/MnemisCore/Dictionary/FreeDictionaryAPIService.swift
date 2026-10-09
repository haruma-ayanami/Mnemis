import Foundation

public enum DictionaryError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
}

/// Free Dictionary API (dictionaryapi.dev). Используется только для обогащения данных.
/// Основное обучение работает без сети (ABOUT.md, раздел 12).
public struct FreeDictionaryAPIService: DictionaryService {
    public static let defaultBaseURL = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/")!

    let baseURL: URL
    let session: URLSession

    public init(baseURL: URL = FreeDictionaryAPIService.defaultBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func entry(for lemma: String) async throws -> DictionaryEntry? {
        let term = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: baseURL.absoluteString + encoded) else {
            throw DictionaryError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw DictionaryError.invalidResponse }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw DictionaryError.httpStatus(http.statusCode) }

        return try FreeDictionaryParser.parse(data)
    }
}

/// Разбор JSON ответа API. Отделён от сети, поэтому покрывается тестами на фикстурах.
enum FreeDictionaryParser {
    static func parse(_ data: Data) throws -> DictionaryEntry? {
        let items = try JSONDecoder().decode([Response].self, from: data)
        guard let item = items.first else { return nil }

        let ipa = item.phonetic ?? item.phonetics?.compactMap(\.text).first { !$0.isEmpty }
        let audioString = item.phonetics?.compactMap(\.audio).first { !$0.isEmpty }
        let meanings = (item.meanings ?? []).flatMap { meaning in
            meaning.definitions.map { definition in
                DictionaryEntry.Meaning(
                    partOfSpeech: meaning.partOfSpeech,
                    definition: definition.definition,
                    example: definition.example,
                    synonyms: (definition.synonyms ?? []) + (meaning.synonyms ?? []),
                    antonyms: (definition.antonyms ?? []) + (meaning.antonyms ?? [])
                )
            }
        }

        return DictionaryEntry(
            lemma: item.word,
            ipa: ipa,
            audioURL: audioString.flatMap { URL(string: $0) },
            meanings: meanings
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
        let partOfSpeech: String
        let definitions: [Definition]
        let synonyms: [String]?
        let antonyms: [String]?
    }

    private struct Definition: Decodable {
        let definition: String
        let example: String?
        let synonyms: [String]?
        let antonyms: [String]?
    }
}
