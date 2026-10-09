import SwiftUI
import SwiftData
import MnemisCore

/// Учебная сессия: повторения и новые слова одной очередью (ABOUT.md, раздел 29).
/// Порядок очереди задаёт `LearnQueue` из MnemisCore.
struct LearnView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.dailyNewWordLimit) private var dailyNewLimit = 5
    @Query private var words: [Word]
    @Query private var progress: [LearningProgress]
    @State private var errorMessage: String?

    private var queue: [Word] {
        LearnQueue.make(words: words, progress: progress, dailyNewLimit: dailyNewLimit)
    }

    var body: some View {
        Group {
            if let next = queue.first {
                FlashcardView(word: next) { rating in
                    rate(rating, for: next)
                }
            } else {
                ContentUnavailableView(
                    "All caught up",
                    systemImage: "checkmark.circle",
                    description: Text("No words are due right now. Come back later.")
                )
            }
        }
        .navigationTitle("Learn")
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    private func rate(_ rating: ReviewRating, for word: Word) {
        do {
            try ReviewService(context: context).rate(wordID: word.id, rating: rating)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
