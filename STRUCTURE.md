# Mnemis — структура проекта

Фактическое устройство кода. Архитектурные решения и правила зависимостей описаны в [ARCHITECTURE.md](ARCHITECTURE.md), продуктовые требования — в [ABOUT.md](ABOUT.md).

Один multiplatform-проект (iPhone, iPad, Mac), без локальных Swift-пакетов.

```text
Mnemis/
├── ABOUT.md, ARCHITECTURE.md, STRUCTURE.md
├── Mnemis.xcodeproj
├── Tools/build_seed.py              сборка words-en-ru.json из NGSL-GR и Wiktionary (kaikki.org)
│
├── Mnemis/
│   ├── App/                         сборка и запуск
│   │   ├── MnemisApp.swift          точка входа
│   │   ├── AppContainer.swift       зависимости, use case'ы, bootstrap
│   │   ├── AppRouter.swift          вкладки и онбординг
│   │   └── RootView.swift           онбординг или TabView
│   │
│   ├── Core/                        логика без UI
│   │   ├── Domain/                  чистые структуры и правила, без SwiftData
│   │   │   ├── Models/              Word, WordProgress, ReviewRecord, ExampleSentence,
│   │   │   │                        DailyWordAssignment, UserSettings
│   │   │   ├── Enums/               LearningStatus, ReviewRating, LanguageCode, WordOrigin
│   │   │   └── Rules/LearningRules  переходы статусов: known, suspend, resume, restore
│   │   ├── Learning/                алгоритм и use case'ы обучения
│   │   │   ├── SpacedRepetitionEngine (протокол), SM2SpacedRepetitionEngine
│   │   │   ├── ReviewScheduler      due-слова и ближайшее повторение
│   │   │   ├── DailyWordSelector    выбор слова дня (чистая функция)
│   │   │   ├── DailyWordUseCase     слово дня на локальный день, сохраняется
│   │   │   ├── LearningSession      состав сессии: повторения + новые слова
│   │   │   ├── SubmitReviewUseCase  оценка: прогресс и история в одной транзакции
│   │   │   ├── WordStatusUseCase    known / suspend / resume
│   │   │   ├── WordEditor           добавление и правка слов и примеров
│   │   │   ├── SettingsUseCase      настройки профиля
│   │   │   └── StreakCalculator     серия по календарным дням
│   │   ├── Persistence/
│   │   │   ├── PersistenceController  ModelContainer, save()
│   │   │   ├── Schema/              SwiftData-классы (*Entity) и маппинг в домен
│   │   │   ├── Repositories/        Word, Progress, Review, DailyWord, Settings
│   │   │   └── Seed/                SeedData: импорт встроенного словаря
│   │   ├── Services/
│   │   │   ├── Dictionary/          DictionaryService (приоритеты), провайдеры,
│   │   │   │                        WordEnrichment (дополнение без перезаписи)
│   │   │   ├── Networking/          APIClient, APIError (таймаут, статусы)
│   │   │   ├── Notifications/       NotificationPlanner (чистое расписание), NotificationService
│   │   │   └── Pronunciation/       SpeechPlayer (системный синтезатор речи, офлайн)
│   │   ├── Search/                  SearchService, TextNormalizer
│   │   ├── DesignSystem/            Typography, Spacing, WordCard, StatTile
│   │   └── Support/                 Clock, LocalDay, Logger
│   │
│   ├── Features/                    экраны: View + ViewModel
│   │   ├── Onboarding/              OnboardingView, OnboardingViewModel
│   │   ├── Today/                   TodayView, TodayViewModel
│   │   ├── Learn/                   LearnView, LearnViewModel, FlashcardView, SessionSummaryView
│   │   ├── Words/                   WordsView, WordsViewModel, WordDetailsView,
│   │   │                            WordDetailsViewModel, AddWordView, EditWordView
│   │   ├── Statistics/              StatisticsView, StatisticsViewModel
│   │   ├── Settings/                SettingsView, SettingsViewModel
│   │   └── Shared/                  EmptyStateView, ErrorStateView, LoadingView, ScreenState
│   │
│   ├── Platform/Shared/             платформенные отличия (например, автозаглавные буквы)
│   │
│   └── Resources/
│       ├── SeedData/                words-en-ru.json, seed-manifest.json (источники и лицензии)
│       ├── Localization/            Localizable.xcstrings
│       ├── Licenses/                THIRD_PARTY_NOTICES.md
│       └── Assets.xcassets
│
├── MnemisTests/
│   ├── UnitTests/                   движок, правила, выбор слова дня, сессия, поиск,
│   │                                серии, словари (с MockURLProtocol)
│   ├── IntegrationTests/            хранение, сценарии пользователя, встроенный словарь
│   └── TestSupport/                 TestClock, MockURLProtocol, Mocks и Fixtures
│
└── MnemisUITests/                   UI-тесты (пока шаблон)
```

## Правила

1. **Домен не знает про SwiftData и UI.** Доменные структуры — в `Core/Domain`, SwiftData-классы — только в `Core/Persistence/Schema`.
2. **Время только через `Clock`.** Не вызывать `Date()` напрямую: тесты используют `TestClock`.
3. **View не ходят в сеть и не содержат правил.** Экран получает ViewModel, ViewModel вызывает use case или репозиторий.
4. **Прогресс и история пишутся одним `save()`.** Use case'ы, которые меняют несколько сущностей, сохраняют их вместе.
5. **Пользовательский контент не перезаписывается API.** Примеры пользователя — отдельные записи, поля обогащаются только если пустые.
6. **Без `@Attribute(.unique)`.** Уникальность проверяется в коде: CloudKit её не поддерживает.

## Что ещё не реализовано

Эти пункты есть в ARCHITECTURE.md, но пока не созданы — чтобы не оставлять пустых заглушек:

- `Core/Services`: файловое аудио из источников, Apple Translation, Tatoeba, импорт/экспорт, синхронизация.
- `Core/Persistence/Migrations` — появится, когда понадобится первая миграция схемы.
- `Platform/iOS`, `Platform/macOS` — пока все различия умещаются в `Platform/Shared`.

## Запуск тестов

Приложение и тесты на симуляторе iOS:

```bash
xcodebuild test -project Mnemis.xcodeproj -scheme Mnemis -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MnemisTests
```

На Mac без симулятора (быстрее):

```bash
xcodebuild test -project Mnemis.xcodeproj -scheme Mnemis -destination 'platform=macOS' -only-testing:MnemisTests
```
