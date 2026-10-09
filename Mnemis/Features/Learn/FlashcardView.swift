import SwiftUI
import MnemisCore

/// Флэшкарта (ABOUT.md, раздел 7): сначала слово, после «Show answer» — перевод и определение, затем оценка.
struct FlashcardView: View {
    let word: Word
    let onRate: (ReviewRating) -> Void

    @State private var isRevealed = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(word.lemma)
                .font(.mnemisWord)

            if isRevealed {
                answer
                    .transition(.opacity)
            } else {
                Button("Show answer") {
                    withAnimation { isRevealed = true }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()

            if isRevealed {
                ratingButtons
            }
        }
        .padding()
        // Сбрасываем «ответ показан» при переходе к следующему слову.
        .id(word.id)
    }

    private var answer: some View {
        VStack(spacing: 10) {
            if let ipa = word.ipa {
                Text(ipa)
                    .font(.mnemisIPA)
                    .foregroundStyle(.secondary)
            }
            Text(word.translation)
                .font(.title3)
            Text(word.definition)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let example = word.examples.first {
                Text(example)
                    .font(.callout.italic())
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            ForEach(ReviewRating.allCases, id: \.self) { rating in
                Button(rating.title) {
                    onRate(rating)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}

private extension ReviewRating {
    var title: LocalizedStringKey {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}
