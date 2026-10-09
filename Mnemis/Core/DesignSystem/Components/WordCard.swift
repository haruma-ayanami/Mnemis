import SwiftUI

/// Главная карточка слова дня: стекло, ASCII-уголки, зелёные метки (ABOUT.md, раздел 22).
struct WordCard: View {
    let word: Word
    var label: LocalizedStringKey = "[ word of the day ]"
    var example: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).bracketLabel(AppColor.accent)

            VStack(alignment: .leading, spacing: 6) {
                Text(word.lemma)
                    .font(.mnemisWord)
                    .tracking(-1.6)
                    .foregroundStyle(AppColor.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(AppColor.ash)
            }

            AsciiDivider()

            MeaningsList(meanings: word.allMeanings)
            if let example {
                Text(highlighted(example))
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.ash)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 26).padding(.bottom, 24)
        .glassCard(cornerRadius: 32)
        .cornerMarks()
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        [word.ipa, word.partsOfSpeechLabel, word.level].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Подсвечивает слово зелёным внутри примера.
    private func highlighted(_ sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        if let range = text.range(of: word.lemma, options: .caseInsensitive) {
            text[range].foregroundColor = AppColor.accent
        }
        return text
    }
}

/// Значения по частям речи: первое крупно, остальные мельче, с короткой зелёной меткой `v`, `n`, `adj`.
/// У слова с одной частью речи метки нет: она уже есть в подписи под словом.
struct MeaningsList: View {
    let meanings: [WordMeaning]
    var primarySize: CGFloat = 19

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(meanings.enumerated()), id: \.offset) { index, meaning in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if meanings.count > 1 {
                        Text(meaning.shortPartOfSpeech)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(AppColor.accent)
                            .frame(width: 28, alignment: .leading)
                    }
                    Text(meaning.translation)
                        .font(.system(size: index == 0 ? primarySize : primarySize - 4, weight: index == 0 ? .medium : .regular))
                        .foregroundStyle(index == 0 ? AppColor.ink : AppColor.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

extension Word {
    /// Части речи для подписи: `noun` или `v · n`, если значений несколько.
    var partsOfSpeechLabel: String? {
        meanings.count > 1 ? meanings.map(\.shortPartOfSpeech).joined(separator: " / ") : partOfSpeech
    }
}
