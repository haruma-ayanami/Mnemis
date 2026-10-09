import SwiftUI
import SwiftData
import MnemisCore

/// Статистика (ABOUT.md, раздел 15). Пока только сводные числа; графики — следующий этап.
struct StatisticsView: View {
    @Query private var progress: [LearningProgress]
    @Query private var reviews: [Review]
    @Query private var words: [Word]

    var body: some View {
        NavigationStack {
            List {
                Section("Words") {
                    LabeledContent("Learned", value: "\(count(.remembered) + count(.known))")
                    LabeledContent("Known", value: "\(count(.known))")
                    LabeledContent("Added by you", value: "\(words.filter { $0.origin == .user }.count)")
                }

                Section("Reviews") {
                    LabeledContent("Total reviews", value: "\(reviews.count)")
                    LabeledContent("Accuracy", value: accuracyText)
                    LabeledContent("Current streak", value: "\(streak) days")
                }
            }
            .navigationTitle("Statistics")
        }
    }

    private func count(_ status: LearningStatus) -> Int {
        progress.filter { $0.status == status }.count
    }

    private var accuracyText: String {
        let correct = progress.reduce(0) { $0 + $1.correctCount }
        let total = progress.reduce(0) { $0 + $1.correctCount + $1.incorrectCount }
        guard total > 0 else { return "—" }
        return "\(Int((Double(correct) / Double(total) * 100).rounded()))%"
    }

    private var streak: Int {
        StreakCalculator.currentStreak(reviewDates: reviews.map(\.reviewedAt))
    }
}
