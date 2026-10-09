import Foundation

/// Найденная идиома: русские переводы, английское толкование и пример (ABOUT.md, раздел 9.1).
struct IdiomEntry: Equatable, Sendable {
    let text: String
    /// Русские переводы из таблицы переводов Викисловаря, без ударений.
    let translations: [String]
    /// Толкование на английском: первое идиоматическое значение.
    let definition: String?
    let example: String?

    /// Что подставить в поле «значение»: русский перевод, а если его нет, английское толкование.
    var suggestedMeaning: String {
        translations.isEmpty ? (definition ?? "") : translations.prefix(3).joined(separator: ", ")
    }
}

protocol IdiomProvider: Sendable {
    func lookup(_ phrase: String) async throws -> IdiomEntry?
}

/// Идиомы из английского Викисловаря через kaikki.org (CC BY-SA). Ключ не нужен:
/// у каждой статьи есть статичный JSONL по адресу `/dictionary/English/meaning/<a>/<ab>/<phrase>.jsonl`.
struct WiktionaryIdiomProvider: IdiomProvider {
    static let baseURL = URL(string: "https://kaikki.org/dictionary/English/meaning/")!
    static let licenseID = "wiktionary-kaikki"

    let client: APIClient
    let baseURL: URL

    init(client: APIClient = APIClient(), baseURL: URL = WiktionaryIdiomProvider.baseURL) {
        self.client = client
        self.baseURL = baseURL
    }

    func lookup(_ phrase: String) async throws -> IdiomEntry? {
        let term = TextNormalizer.normalize(phrase)
        guard term.count >= 3, term.contains(" "), let url = Self.url(for: term, baseURL: baseURL) else { return nil }
        do {
            return WiktionaryIdiomParser.parse(try await client.data(from: url), phrase: term)
        } catch APIError.notFound {
            return nil
        }
    }

    /// Путь kaikki: первая буква, первые две буквы, затем сама статья.
    static func url(for term: String, baseURL: URL) -> URL? {
        let first = String(term.prefix(1))
        let firstTwo = String(term.prefix(2))
        let path = [first, firstTwo, term + ".jsonl"]
            .compactMap { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(["/"])) }
            .joined(separator: "/")
        return URL(string: baseURL.absoluteString + path)
    }
}

/// Разбор JSONL kaikki. Отделён от сети, поэтому проверяется тестами на фикстурах.
enum WiktionaryIdiomParser {
    private static let stress = CharacterSet(charactersIn: "\u{0300}\u{0301}")

    static func parse(_ data: Data, phrase: String) -> IdiomEntry? {
        let decoder = JSONDecoder()
        let entries = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { try? decoder.decode(Entry.self, from: Data($0.utf8)) }
            .filter { TextNormalizer.normalize($0.word) == phrase }
        guard !entries.isEmpty else { return nil }

        // Сначала значения с пометкой «idiomatic», затем остальные, кроме буквального «see break, the, ice».
        let senses = entries.flatMap { $0.senses ?? [] }.filter { !($0.glosses?.first ?? "").hasPrefix("Used other than") }
        let sense = senses.first { $0.tags?.contains("idiomatic") == true } ?? senses.first
        let definition = sense?.glosses?.first.map(trimmed)
        let example = sense?.examples?
            .compactMap(\.text)
            .map { $0.split(whereSeparator: \.isNewline).first.map(String.init) ?? $0 }
            .first { $0.count <= 160 && !$0.contains("ſ") && $0.localizedCaseInsensitiveContains(phrase.split(separator: " ").first ?? "") }

        var translations: [String] = []
        for translation in entries.flatMap({ $0.translations ?? [] }) where translation.langCode == "ru" {
            guard let word = translation.word.map(stripStress), !word.isEmpty, !translations.contains(word) else { continue }
            translations.append(word)
        }

        guard definition != nil || !translations.isEmpty else { return nil }
        return IdiomEntry(text: entries[0].word, translations: translations, definition: definition, example: example)
    }

    private static func stripStress(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { !stress.contains($0) }))
            .trimmingCharacters(in: .whitespaces)
    }

    private static func trimmed(_ gloss: String) -> String {
        var text = gloss.trimmingCharacters(in: .whitespaces)
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    private struct Entry: Decodable {
        let word: String
        let senses: [Sense]?
        let translations: [Translation]?
    }

    private struct Sense: Decodable {
        let glosses: [String]?
        let tags: [String]?
        let examples: [Example]?
    }

    private struct Example: Decodable {
        let text: String?
    }

    private struct Translation: Decodable {
        let langCode: String?
        let word: String?

        enum CodingKeys: String, CodingKey {
            case langCode = "lang_code"
            case word
        }
    }
}
