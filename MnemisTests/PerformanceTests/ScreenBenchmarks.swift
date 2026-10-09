import Foundation
import SwiftUI
import Testing
@testable import Mnemis

/// Замеры экранов на полном встроенном словаре и истории за несколько месяцев.
/// Тесты ничего не утверждают: печатают медианы в лог, чтобы сравнивать до и после оптимизации.
@MainActor
struct ScreenBenchmarks {
    let clock = TestClock()

    /// Полный словарь, прогресс по 1200 словам и 5000 записей истории повторений.
    private func makeLoadedContainer() throws -> AppContainer {
        let container = try AppContainer.inMemory(clock: clock)
        let contents = try SeedBundle.load()
        _ = try SeedDataImporter(words: container.words, persistence: container.persistence)
            .importWords(contents.words, manifest: contents.manifest, now: clock.now)

        let words = try container.words.allWords()
        let statuses: [LearningStatus] = [.learning, .reviewing, .remembered, .known]
        for (index, word) in words.prefix(1200).enumerated() {
            var progress = WordProgress(wordID: word.id, createdAt: clock.now)
            progress.status = statuses[index % statuses.count]
            progress.introducedAt = clock.now.addingTimeInterval(-Double(index % 120) * 86_400)
            progress.nextReviewAt = clock.now.addingTimeInterval(Double(index % 9 - 2) * 86_400)
            try container.progress.upsert(progress)
        }
        let history = (0..<5000).map { index in
            ReviewRecord(
                wordID: words[index % 1200].id,
                reviewedAt: clock.now.addingTimeInterval(-Double(index) * 2_000),
                rating: index % 7 == 0 ? .again : .good,
                previousIntervalDays: 1,
                scheduledIntervalDays: 3
            )
        }
        for record in history {
            container.reviews.append(record)
        }
        // Сводку строим так же, как при оценках в приложении.
        try container.dailyActivity.rebuild(from: history, calendar: clock.calendar)
        try container.persistence.save()
        return container
    }

    private func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
    }

    /// Медиана из пяти прогонов: один замер шумит.
    private func medianMilliseconds(_ body: () throws -> Void) rethrows -> Double {
        var samples: [Double] = []
        for _ in 0..<5 {
            let start = ContinuousClock.now
            try body()
            samples.append(milliseconds(ContinuousClock.now - start))
        }
        return samples.sorted()[2]
    }

    @Test func screenLoadTimes() throws {
        let container = try makeLoadedContainer()
        var report: [(String, Double)] = []

        let today = try medianMilliseconds { TodayViewModel(container: container).load() }
        report.append(("Today.load", today))

        let wordsLoad = try medianMilliseconds { WordsViewModel(container: container).load() }
        report.append(("Words.load", wordsLoad))

        let search = try medianMilliseconds { _ = try container.words.search("ab", limit: WordsViewModel.searchLimit) }
        report.append(("Words.search(ab)", search))

        let page = try medianMilliseconds { _ = try container.words.page(offset: 0, limit: WordsViewModel.pageSize) }
        report.append(("Words.page", page))

        let statistics = try medianMilliseconds { StatisticsViewModel(container: container).load() }
        report.append(("Statistics.load", statistics))

        let settings = try medianMilliseconds { SettingsViewModel(container: container).load() }
        report.append(("Settings.load", settings))

        let seed = try medianMilliseconds { _ = try SeedBundle.load() }
        report.append(("SeedBundle.load", seed))

        let sphere = medianMilliseconds {
            _ = ImageRenderer(content: DotSphere(dotCount: 2600).frame(width: 300, height: 300)).cgImage
        }
        report.append(("DotSphere.render(2600)", sphere))

        let rings = medianMilliseconds {
            _ = ImageRenderer(content: DotRings().frame(width: 640, height: 640)).cgImage
        }
        report.append(("DotRings.render(640)", rings))

        let learnStart = try medianMilliseconds { LearnViewModel(container: container).startIfNeeded() }
        report.append(("Learn.start", learnStart))

        let learn = LearnViewModel(container: container)
        learn.startIfNeeded()
        let rateFive = try medianMilliseconds {
            for _ in 0..<5 { learn.rate(.good) }
        }
        report.append(("Learn.rate x5", rateFive))

        let lines = report.map { "\($0.0) \(format($0.1)) ms" }
        Attachment.record(lines.joined(separator: "\n"), named: "screen-benchmarks.txt")
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
