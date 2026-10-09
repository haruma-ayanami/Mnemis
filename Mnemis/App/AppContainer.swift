import SwiftUI
import OSLog
import Foundation

/// Сборка зависимостей приложения. Простого контейнера достаточно: DI-фреймворк здесь не нужен (ARCHITECTURE.md, раздел 15).
@MainActor
final class AppContainer {
    let persistence: PersistenceController
    let clock: any Clock
    let engine: any SpacedRepetitionEngine
    let dictionary: DictionaryService
    let router: AppRouter
    let notifications: NotificationService

    let words: WordRepository
    let progress: ProgressRepository
    let reviews: ReviewRepository
    let dailyWords: DailyWordRepository
    let settingsRepository: SettingsRepository

    init(
        persistence: PersistenceController,
        clock: any Clock = SystemClock(),
        engine: any SpacedRepetitionEngine = SM2SpacedRepetitionEngine(),
        dictionary: DictionaryService? = nil
    ) {
        let context = persistence.context
        let words = WordRepository(context: context)

        self.persistence = persistence
        self.clock = clock
        self.engine = engine
        self.words = words
        self.progress = ProgressRepository(context: context)
        self.reviews = ReviewRepository(context: context)
        self.dailyWords = DailyWordRepository(context: context)
        self.settingsRepository = SettingsRepository(context: context)
        self.dictionary = dictionary ?? DictionaryService(providers: [
            LocalDictionaryProvider(words: words),
            FreeDictionaryProvider(),
        ])
        let router = AppRouter()
        self.router = router
        self.notifications = NotificationService()
        self.notifications.onOpenLearn = { router.selectedTab = .learn }
    }

    /// Пересоздаёт расписание уведомлений по текущим настройкам.
    func refreshNotifications() async {
        guard let settings = try? settings.load() else { return }
        await notifications.apply(settings: settings)
    }

    static func live() throws -> AppContainer {
        AppContainer(persistence: try PersistenceController.make())
    }

    static func inMemory(clock: any Clock = SystemClock(), dictionary: DictionaryService? = nil) throws -> AppContainer {
        AppContainer(persistence: try PersistenceController.make(inMemory: true), clock: clock, dictionary: dictionary)
    }

    // MARK: - Use cases

    var submitReview: SubmitReviewUseCase {
        SubmitReviewUseCase(progress: progress, reviews: reviews, persistence: persistence, engine: engine, clock: clock)
    }

    var wordStatus: WordStatusUseCase {
        WordStatusUseCase(progress: progress, persistence: persistence, clock: clock)
    }

    var dailyWordUseCase: DailyWordUseCase {
        DailyWordUseCase(words: words, progress: progress, dailyWords: dailyWords, persistence: persistence, clock: clock)
    }

    var wordEditor: WordEditor {
        WordEditor(words: words, persistence: persistence, clock: clock)
    }

    var wordEnrichment: WordEnrichment {
        WordEnrichment(dictionary: dictionary, words: words, persistence: persistence, clock: clock)
    }

    var settings: SettingsUseCase {
        SettingsUseCase(settings: settingsRepository, persistence: persistence)
    }

    // MARK: - Запуск

    /// Загружает встроенный словарь и восстанавливает состояние онбординга.
    /// Ошибки логируются, но не останавливают запуск: приложение должно открыться даже без данных.
    func bootstrap() {
        do {
            // Словарь уже загружен: не читаем всю базу при каждом запуске.
            guard try words.count() == 0 else { throw SeedSkip() }
            let contents = try SeedBundle.load()
            let added = try SeedDataImporter(words: words, persistence: persistence)
                .importWords(contents.words, manifest: contents.manifest, now: clock.now)
            Log.persistence.info("Built-in dictionary: \(added, privacy: .public) new words")
        } catch is SeedSkip {
            // Ничего не делаем.
        } catch {
            Log.persistence.error("Built-in dictionary import failed: \(String(describing: error), privacy: .public)")
        }

        do {
            let settings = try self.settings.load()
            router.isOnboarded = settings.onboardingCompleted
            router.colorScheme = Self.colorScheme(for: settings.preferredTheme)
        } catch {
            Log.persistence.error("Settings load failed: \(String(describing: error), privacy: .public)")
        }
    }

    static func colorScheme(for theme: ThemePreference) -> ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Внутренний сигнал: импорт встроенного словаря не нужен.
private struct SeedSkip: Error {}
