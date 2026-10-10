import Foundation

/// Тип упражнения: что дано и что нужно выбрать (ABOUT.md, раздел 7.1).
enum PracticeKind: Equatable, Sendable {
    /// Дано слово, выбрать значение по-русски.
    case meaning
    /// Дано значение по-русски, выбрать слово.
    case reverse
    /// Дано предложение с пропуском, выбрать слово или идиому.
    case context
}

/// Вариант ответа: слово (для обратных вопросов) или его значение.
struct PracticeOption: Equatable, Sendable {
    let wordID: UUID
    let text: String
}

/// Один вопрос упражнения. Правильный вариант — тот, у которого `wordID` совпадает с `wordID` вопроса.
struct PracticeQuestion: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: PracticeKind
    let wordID: UUID
    let prompt: String
    let options: [PracticeOption]

    func isCorrect(_ option: PracticeOption) -> Bool { option.wordID == wordID }
}

/// Детерминированный генератор для тестов и повторяемых сессий (SplitMix64).
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Собирает упражнения из слов, которые пользователь учит. Чистая логика: без базы и без сети.
enum PracticeBuilder {
    /// Сколько вариантов в каждом вопросе (правильный и три отвлекающих).
    static let optionCount = 4

    /// Русский перевод одной строкой: первое значение до запятой. Для вариантов ответа.
    static func shortMeaning(of word: Word) -> String? {
        guard let first = word.allMeanings.first?.translation else { return nil }
        let head = first.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return head.isEmpty ? nil : head
    }

    /// Вопросы по целям. `primary` — слова, которые учит пользователь; `secondary` — закреплённые,
    /// они добавляются, если основных не хватает; `bonus` — уже знакомые, не больше одного вопроса.
    static func questions(
        primary: [Word],
        secondary: [Word] = [],
        bonus: [Word] = [],
        pool: [Word],
        examples: [UUID: [String]],
        count: Int,
        seed: UInt64
    ) -> [PracticeQuestion] {
        var random = SeededRandom(seed: seed)
        var targets = primary.shuffled(using: &random)
        if targets.count < count {
            targets += secondary.shuffled(using: &random)
        }
        targets = Array(targets.prefix(count))
        if seed % 4 == 0, let known = bonus.randomElement(using: &random), !targets.contains(where: { $0.id == known.id }) {
            targets.append(known)
        }

        var result: [PracticeQuestion] = []
        for target in targets {
            guard let question = make(for: target, pool: pool, examples: examples[target.id] ?? [], random: &random) else { continue }
            result.append(question)
        }
        return result
    }

    static func make(
        for target: Word,
        pool: [Word],
        examples: [String],
        random: inout SeededRandom
    ) -> PracticeQuestion? {
        guard let meaning = shortMeaning(of: target) else { return nil }
        let sentence = examples.first { contains(target.lemma, in: $0) }

        var kinds: [PracticeKind] = [.meaning, .reverse]
        if sentence != nil { kinds.append(.context) }
        let kind = kinds.randomElement(using: &random) ?? .meaning

        let distractors = distractorWords(for: target, pool: pool, random: &random)
        guard distractors.count == optionCount - 1 else { return nil }

        let correctText: String
        let distractorTexts: [String]
        let prompt: String
        switch kind {
        case .meaning:
            prompt = target.lemma
            correctText = meaning
            distractorTexts = distractors.compactMap(shortMeaning(of:))
        case .reverse:
            prompt = meaning
            correctText = target.lemma
            distractorTexts = distractors.map(\.lemma)
        case .context:
            prompt = blank(target.lemma, in: sentence ?? target.lemma)
            correctText = target.lemma
            distractorTexts = distractors.map(\.lemma)
        }
        guard distractorTexts.count == optionCount - 1 else { return nil }

        var options = [PracticeOption(wordID: target.id, text: correctText)]
        options += zip(distractors, distractorTexts).map { PracticeOption(wordID: $0.id, text: $1) }
        options.shuffle(using: &random)
        return PracticeQuestion(id: UUID(), kind: kind, wordID: target.id, prompt: prompt, options: options)
    }

    /// Отвлекающие слова: того же вида (слово или идиома) и части речи, если таких хватает. Без повторов текста.
    static func distractorWords(for target: Word, pool: [Word], random: inout SeededRandom) -> [Word] {
        let candidates = pool.filter { $0.id != target.id && $0.lemma.lowercased() != target.lemma.lowercased() }
        let sameKind = candidates.filter { $0.isIdiom == target.isIdiom }
        let samePart = sameKind.filter { $0.partOfSpeech == target.partOfSpeech }
        var chosen: [Word] = []
        var usedLemmas: Set<String> = [target.lemma.lowercased()]
        var usedMeanings: Set<String> = [shortMeaning(of: target) ?? ""]

        for group in [samePart.shuffled(using: &random), sameKind.shuffled(using: &random), candidates.shuffled(using: &random)] {
            for word in group where chosen.count < optionCount - 1 {
                let meaning = shortMeaning(of: word) ?? ""
                guard !meaning.isEmpty, !usedMeanings.contains(meaning), !usedLemmas.contains(word.lemma.lowercased()) else { continue }
                chosen.append(word)
                usedLemmas.insert(word.lemma.lowercased())
                usedMeanings.insert(meaning)
            }
        }
        return chosen
    }

    /// Слово в предложении, без учёта регистра и с границами слов (для идиом — целая фраза).
    static func contains(_ lemma: String, in sentence: String) -> Bool {
        sentence.range(of: lemma, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func blank(_ lemma: String, in sentence: String) -> String {
        guard let range = sentence.range(of: lemma, options: [.caseInsensitive, .diacriticInsensitive]) else { return sentence }
        return sentence.replacingCharacters(in: range, with: "____")
    }
}
