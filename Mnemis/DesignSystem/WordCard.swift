import SwiftUI
import MnemisCore

/// Карточка слова (ABOUT.md, раздел 22): минимум элементов, Liquid Glass только на фоне карточки.
struct WordCard: View {
    let word: Word
    var label: LocalizedStringKey = "TODAY"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.mnemisLabel)
                .foregroundStyle(.secondary)

            Text(word.lemma)
                .font(.mnemisWord)

            if let ipa = word.ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(.mnemisIPA)
                    .foregroundStyle(.secondary)
            }

            if !word.translation.isEmpty {
                Text(word.translation)
                    .font(.title3)
            }

            if !word.definition.isEmpty {
                Text(word.definition)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let example = word.examples.first {
                Text(example)
                    .font(.callout.italic())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
