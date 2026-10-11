import Foundation
import Observation
import OSLog

/// Состояние поиска в Викисловаре на первом шаге.
enum EntryLookupState: Equatable {
    case idle
    case searching
    case found
    case notFound
    case offline
}

/// Строка карточки «found» на первом шаге: что нашлось и что осталось заполнить самому.
struct FoundRow: Equatable, Identifiable {
    let title: String
    let value: String
    let isFound: Bool
    var id: String { title }
}

/// Три шага добавления: слово → детали → проверка (холст: Add-Word, Add-Word-Details, Add-Word-Review).
/// Всё найденное подставляется само и правится; пока поле не тронуто, новая находка его заменяет.
@MainActor
@Observable
final class AddEntryViewModel {
    enum Step: Int, CaseIterable {
        case word = 1
        case details
        case review
    }

    static let partsOfSpeech = ["noun", "verb", "adjective", "adverb", "preposition", "pronoun", "conjunction", "interjection"]
    static let levels = ["A1", "A2", "B1", "B2", "C1"]

    private let container: AppContainer

    var kind: EntryKind
    var text: String
    private(set) var step: Step = .word
    private(set) var lookup: EntryLookupState = .idle
    private(set) var existing: Word?

    var ipa = ""
    private(set) var partOfSpeech: String?
    var level: String?
    var translation = ""
    var definition = ""
    var example = ""
    /// Пример из Викисловаря: предлагается кнопкой «Use», пока не вставлен.
    private(set) var suggestion: String?

    private var autoIPA: String?
    private var autoTranslation: String?
    private var autoDefinition: String?
    private var wordEntry: WordLookupEntry?
    private var idiomEntry: IdiomEntry?
    /// Данные пришли из Викисловаря хотя бы раз: запись получит его лицензию.
    private var usedWiktionary = false

    init(container: AppContainer, kind: EntryKind, text: String) {
        self.container = container
        self.kind = kind
        self.text = text
        refreshDuplicate()
    }

    // MARK: - Шаги

    var title: String { kind == .word ? "New word" : "New idiom" }
    var isFirstStep: Bool { step == .word }
    var isLastStep: Bool { step == .review }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canContinue: Bool {
        switch step {
        case .word: !trimmedText.isEmpty && existing == nil
        case .details: kind == .word || !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .review: canAdd
        }
    }

    var canAdd: Bool {
        !trimmedText.isEmpty && existing == nil
            && (kind == .word || !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func next() {
        guard canContinue, let following = Step(rawValue: step.rawValue + 1) else { return }
        step = following
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    // MARK: - Поиск

    /// Меняет вид записи: найденное для прежнего вида сбрасывается, поиск запускается заново.
    func setKind(_ newKind: EntryKind) {
        guard newKind != kind else { return }
        kind = newKind
        clearAuto()
        lookup = .idle
    }

    func textChanged() {
        refreshDuplicate()
    }

    private func refreshDuplicate() {
        let key = TextNormalizer.normalize(trimmedText)
        existing = key.isEmpty ? nil : (try? container.words.words(normalizedLemma: key))?.first
    }

    /// Ищет слово или идиому после короткой паузы в наборе. Новый ввод отменяет прошлый поиск через `.task(id:)`.
    func search() async {
        let query = trimmedText
        guard !query.isEmpty, existing == nil, kind == .word || query.contains(" ") else {
            clearAuto()
            lookup = .idle
            return
        }
        lookup = .searching
        do {
            try await Task.sleep(for: .milliseconds(450))
            switch kind {
            case .word:
                let entry = try await container.wordLookup.lookup(query)
                guard !Task.isCancelled else { return }
                applyWord(entry)
            case .idiom:
                let entry = try await container.idioms.lookup(query)
                guard !Task.isCancelled else { return }
                applyIdiom(entry)
            }
        } catch is CancellationError {
            // Пользователь продолжил печатать.
        } catch {
            Log.network.error("Entry lookup failed: \(String(describing: error), privacy: .public)")
            clearAuto()
            lookup = .offline
        }
    }

    private func applyWord(_ entry: WordLookupEntry?) {
        wordEntry = entry
        idiomEntry = nil
        guard let entry else {
            clearAuto()
            lookup = .notFound
            return
        }
        usedWiktionary = true
        partOfSpeech = partOfSpeech.flatMap { current in entry.senses.contains { $0.partOfSpeech == current } ? current : nil }
            ?? entry.senses.first?.partOfSpeech
        ipa = merged(current: ipa, auto: &autoIPA, new: entry.ipa)
        fillSense(entry.sense(for: partOfSpeech))
        lookup = .found
    }

    private func applyIdiom(_ entry: IdiomEntry?) {
        idiomEntry = entry
        wordEntry = nil
        guard let entry else {
            clearAuto()
            lookup = .notFound
            return
        }
        usedWiktionary = true
        translation = merged(current: translation, auto: &autoTranslation, new: entry.suggestedMeaning)
        definition = merged(current: definition, auto: &autoDefinition, new: entry.definition)
        suggestion = entry.example
        lookup = .found
    }

    private func fillSense(_ sense: WordLookupSense?) {
        translation = merged(current: translation, auto: &autoTranslation, new: sense?.translations.prefix(3).joined(separator: ", "))
        definition = merged(current: definition, auto: &autoDefinition, new: sense?.definition)
        suggestion = sense?.example
    }

    /// Новое значение заменяет поле, если оно пустое или осталось таким, каким его подставил словарь.
    private func merged(current: String, auto: inout String?, new: String?) -> String {
        let value = new ?? ""
        guard current.isEmpty || current == auto else { return current }
        auto = value.isEmpty ? nil : value
        return value
    }

    /// Убирает подставленное словарём, не трогая то, что пользователь написал сам.
    private func clearAuto() {
        if ipa == autoIPA { ipa = "" }
        if translation == autoTranslation { translation = "" }
        if definition == autoDefinition { definition = "" }
        autoIPA = nil
        autoTranslation = nil
        autoDefinition = nil
        suggestion = nil
        wordEntry = nil
        idiomEntry = nil
        if kind == .idiom { partOfSpeech = nil }
    }

    // MARK: - Поля

    func select(partOfSpeech part: String) {
        partOfSpeech = part
        if let entry = wordEntry, entry.senses.contains(where: { $0.partOfSpeech == part }) {
            fillSense(entry.sense(for: part))
        }
    }

    func selectLevel(_ value: String) {
        level = level == value ? nil : value
    }

    var ipaIsAuto: Bool { !ipa.isEmpty && ipa == autoIPA }
    var translationIsAuto: Bool { !translation.isEmpty && translation == autoTranslation }
    var definitionIsAuto: Bool { !definition.isEmpty && definition == autoDefinition }

    var showsSuggestion: Bool {
        guard let suggestion else { return false }
        return example.trimmingCharacters(in: .whitespacesAndNewlines) != suggestion
    }

    func useSuggestion() {
        guard let suggestion else { return }
        example = suggestion
    }

    // MARK: - Показ

    var foundLabel: String { "[ found in wiktionary ]" }

    var sourceLine: String { "source · Wiktionary via kaikki.org · CC BY-SA" }

    /// Что нашлось. Слово: перевод, транскрипция, часть речи, определение, пример. Идиома: значение, определение, пример.
    var foundRows: [FoundRow] {
        switch kind {
        case .word:
            let sense = wordEntry?.sense(for: partOfSpeech)
            let translations = sense?.translations ?? []
            let shortTranslation = translations.first.map { translations.count > 1 ? $0 + "…" : $0 }
            return [
                FoundRow(title: "translation", value: shortTranslation ?? "–", isFound: shortTranslation != nil),
                FoundRow(title: "transcription", value: wordEntry?.ipa ?? "–", isFound: wordEntry?.ipa != nil),
                FoundRow(title: "part of speech · level", value: partOfSpeech ?? "–", isFound: partOfSpeech != nil),
                FoundRow(title: "definition", value: sense?.definition != nil ? "found" : "–", isFound: sense?.definition != nil),
                FoundRow(title: "example", value: sense?.example != nil ? "suggested" : "–", isFound: sense?.example != nil),
            ]
        case .idiom:
            let hasRussian = idiomEntry?.translations.isEmpty == false
            return [
                FoundRow(title: "meaning", value: hasRussian ? "русский" : (idiomEntry?.definition != nil ? "english" : "–"), isFound: !(idiomEntry?.suggestedMeaning ?? "").isEmpty),
                FoundRow(title: "definition", value: idiomEntry?.definition != nil ? "found" : "–", isFound: idiomEntry?.definition != nil),
                FoundRow(title: "example", value: idiomEntry?.example != nil ? "suggested" : "–", isFound: idiomEntry?.example != nil),
            ]
        }
    }

    var previewMeta: String { kind == .word ? ipa : "idiom" }

    /// Пилюли превью: часть речи и уровень, как на карточке слова.
    var previewPills: [String] {
        var items: [String] = []
        if kind == .idiom {
            items.append("idiom")
        } else if let partOfSpeech {
            items.append(partOfSpeech)
        }
        if let level { items.append(level) }
        return items
    }

    // MARK: - Сохранение

    /// Создаёт запись. Слово дополняется из других источников в фоне, без сети оно остаётся как есть.
    func save() throws -> Word {
        let details = NewEntryDetails(
            partOfSpeech: kind == .word ? partOfSpeech : nil,
            level: level,
            ipa: kind == .word ? ipa : nil,
            definition: definition,
            fromWiktionary: usedWiktionary
        )
        switch kind {
        case .word:
            let word = try container.wordEditor.addWord(lemma: text, translation: translation, example: example, details: details)
            let enrichment = container.wordEnrichment
            Task { _ = try? await enrichment.enrich(wordID: word.id) }
            return word
        case .idiom:
            return try container.wordEditor.addIdiom(text: text, meaning: translation, example: example, details: details)
        }
    }
}
