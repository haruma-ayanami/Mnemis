import OSLog
import Foundation

/// Сведения о слове из одного источника. Внешние DTO сюда не попадают: провайдер сам переводит их в эту структуру.
struct DictionaryEntry: Equatable, Sendable {
    var lemma: String
    var ipa: String?
    var audioURL: URL?
    var partOfSpeech: String?
    var definition: String?
    var examples: [String]
    var sourceID: String
    var licenseID: String
}

/// Один источник данных. `nil` означает «слова нет» — это штатный исход, а не ошибка.
protocol DictionaryProvider {
    var sourceID: String { get }
    func entry(for lemma: String) async throws -> DictionaryEntry?
}

enum LookupResult: Equatable {
    case found(DictionaryEntry)
    case notFound
    /// Ни один источник не ответил из-за сети или ошибки. Это не значит, что слова нет.
    case unavailable
}

/// Поиск по источникам по приоритету (ABOUT.md, раздел 8):
/// пользовательские данные → локальный словарь и кэш → внешние источники.
struct DictionaryService {
    let providers: [any DictionaryProvider]

    /// Первый источник, который вернул слово, побеждает. Ошибка одного источника не блокирует следующий.
    func lookup(_ lemma: String) async -> LookupResult {
        var hadFailure = false
        for provider in providers {
            do {
                if let entry = try await provider.entry(for: lemma) {
                    return .found(entry)
                }
            } catch {
                hadFailure = true
                Log.network.error("Dictionary provider \(provider.sourceID, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
        }
        return hadFailure ? .unavailable : .notFound
    }
}
