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
    let idioms: any IdiomProvider
    let router: AppRouter
    let notifications: NotificationService
    let account: AccountService

    let words: WordRepository
    let progress: ProgressRepository
    let reviews: ReviewRepository
    let dailyWords: DailyWordRepository
    let settingsRepository: SettingsRepository
    let dailyActivity: DailyActivityRepository
    let phrases: PhraseRepository

    init(
        persistence: PersistenceController,
        clock: any Clock = SystemClock(),
        engine: any SpacedRepetitionEngine = SM2SpacedRepetitionEngine(),
        dictionary: DictionaryService? = nil,
        idioms: any IdiomProvider = WiktionaryIdiomProvider(),
        accountStore: AccountStore = KeychainAccountStore()
    ) {
        self.idioms = idioms
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
        self.dailyActivity = DailyActivityRepository(context: context)
        self.phrases = PhraseRepository(context: context)
        self.dictionary = dictionary ?? DictionaryService(providers: [
            LocalDictionaryProvider(words: words),
            FreeDictionaryProvider(),
        ])
        let router = AppRouter()
        self.router = router
        self.notifications = NotificationService()
        self.notifications.onOpenLearn = { router.startSession() }
        self.account = AccountService(store: accountStore)
    }

    /// Пересоздаёт расписание уведомлений по текущим настройкам.
    func refreshNotifications() async {
        guard let settings = try? settings.load() else { return }
        await notifications.apply(settings: settings)
    }

    static func live() throws -> AppContainer {
        AppContainer(persistence: try PersistenceController.make())
    }

    /// Запуск приложения: хранилище открывается вне главного потока (на большой базе это около секунды),
    /// поэтому первый кадр не ждёт его и показывает фон приложения, а не белый экран.
    static func launch() async throws -> AppContainer {
        let modelContainer = try await Task.detached(priority: .userInitiated) {
            try PersistenceController.makeModelContainer()
        }.value
        let container = AppContainer(persistence: PersistenceController(container: modelContainer))
        container.bootstrap()
        return container
    }

    static func inMemory(clock: any Clock = SystemClock(), dictionary: DictionaryService? = nil) throws -> AppContainer {
        AppContainer(
            persistence: try PersistenceController.make(inMemory: true),
            clock: clock,
            dictionary: dictionary,
            accountStore: InMemoryAccountStore()
        )
    }

    // MARK: - Use cases

    var submitReview: SubmitReviewUseCase {
        SubmitReviewUseCase(
            progress: progress,
            reviews: reviews,
            activity: dailyActivity,
            persistence: persistence,
            engine: engine,
            clock: clock
        )
    }

    var phraseEditor: PhraseEditor {
        PhraseEditor(phrases: phrases, persistence: persistence, clock: clock)
    }

    var studyQueue: StudyQueueUseCase {
        StudyQueueUseCase(words: words, progress: progress, clock: clock)
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
            UserDefaults.standard.set(contents.manifest.seedVersion ?? 1, forKey: Self.seedVersionKey)
            Log.persistence.info("Built-in dictionary: \(added, privacy: .public) new words")
        } catch is SeedSkip {
            // Ничего не делаем.
        } catch {
            Log.persistence.error("Built-in dictionary import failed: \(String(describing: error), privacy: .public)")
        }

        do {
            try refreshSeedIfNeeded()
        } catch {
            Log.persistence.error("Built-in dictionary refresh failed: \(String(describing: error), privacy: .public)")
        }

        do {
            try repairDerivedDataIfNeeded()
        } catch {
            Log.persistence.error("Derived data repair failed: \(String(describing: error), privacy: .public)")
        }

        do {
            let settings = try self.settings.load()
            router.isOnboarded = settings.onboardingCompleted
            router.colorScheme = Self.colorScheme(for: settings.preferredTheme)
        } catch {
            Log.persistence.error("Settings load failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Версия производных данных: сводка активности и флаги «слово начато» и `sortRank`.
    /// Пересчитываем один раз на версию, а не при каждом запуске.
    static let derivedDataVersion = 3
    private static let derivedDataVersionKey = "mnemis.derivedDataVersion"

    private func repairDerivedDataIfNeeded(defaults: UserDefaults = .standard) throws {
        guard defaults.integer(forKey: Self.derivedDataVersionKey) < Self.derivedDataVersion else { return }

        try words.refreshDerivedFields()
        try progress.refreshDerivedFields()
        try dailyActivity.rebuild(from: try reviews.all(), calendar: clock.calendar)
        for item in try progress.all() {
            try progress.markWordStarted(item.wordID)
        }
        try persistence.save()
        defaults.set(Self.derivedDataVersion, forKey: Self.derivedDataVersionKey)
        Log.persistence.info("Derived data rebuilt to version \(Self.derivedDataVersion, privacy: .public)")
    }

    /// Версия встроенного словаря, до которой уже обновлена база. Новая версия в бандле обновляет слова один раз.
    private static let seedVersionKey = "mnemis.seedVersion"

    private func refreshSeedIfNeeded(defaults: UserDefaults = .standard, bundle: Bundle = .main) throws {
        // До версии 2 номер не сохранялся: 0 значит «словарь первой версии».
        let bundled = try SeedBundle.loadManifest(bundle: bundle).seedVersion ?? 1
        guard defaults.integer(forKey: Self.seedVersionKey) < bundled else { return }

        let contents = try SeedBundle.load(bundle: bundle)
        let started = Set(try progress.all().map(\.wordID))
        let result = try SeedDataImporter(words: words, persistence: persistence)
            .refresh(contents.words, manifest: contents.manifest, startedWordIDs: started, now: clock.now)
        defaults.set(bundled, forKey: Self.seedVersionKey)
        Log.persistence.info("Built-in dictionary v\(bundled, privacy: .public): \(result.updated, privacy: .public) updated, \(result.added, privacy: .public) added, \(result.removed, privacy: .public) removed")
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
