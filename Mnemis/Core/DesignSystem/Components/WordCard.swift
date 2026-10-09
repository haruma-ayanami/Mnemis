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

            if !word.translation.isEmpty {
                Text(word.translation)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppColor.ink)
            }
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
        [word.ipa, word.partOfSpeech, word.level].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
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
