import SwiftUI
import SwiftData
import MnemisCore

/// Главный экран: Daily Word, число слов к повторению и серия дней (ABOUT.md, раздел 15).
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.level) private var levelRaw = LanguageLevel.defaultValue.rawValue
    @Query private var progress: [LearningProgress]
    @Query private var reviews: [Review]
    @State private var dailyWord: Word?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let dailyWord {
                        WordCard(word: dailyWord)
                    } else {
                        ContentUnavailableView(
                            "No word for today",
                            systemImage: "book.closed",
                            description: Text("Add a word in Words to start.")
                        )
                    }

                    HStack(spacing: 16) {
                        StatTile(title: "Due", value: dueCount)
                        StatTile(title: "Streak", value: streak)
                    }

                    NavigationLink {
                        LearnView()
                    } label: {
                        Label("Learn", systemImage: "rectangle.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .task { loadDailyWord() }
        }
    }

    private var dueCount: Int {
        let now = Date.now
        return progress.filter { $0.isDue(at: now) }.count
    }

    private var streak: Int {
        StreakCalculator.currentStreak(reviewDates: reviews.map(\.reviewedAt))
    }

    private func loadDailyWord() {
        do {
            dailyWord = try DailyWordService(context: context).word(preferredLevel: levelRaw)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
