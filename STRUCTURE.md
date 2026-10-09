# Mnemis — структура проекта

Проект разделён на две части:

- **Mnemis** (Xcode-таргет) — всё, что видит пользователь: экраны, дизайн, ресурсы.
- **MnemisCore** (локальный Swift-пакет) — данные и логика без UI: модели, алгоритм повторений, словарь, поиск.

Приложение зависит от ядра, ядро ничего не знает о приложении. Поэтому логику можно тестировать через `swift test` за доли секунды, без симулятора.

```text
Mnemis/
├── ABOUT.md                      продуктовая спецификация
├── STRUCTURE.md                  этот файл
├── Mnemis.xcodeproj
│
├── Mnemis/                       приложение (SwiftUI)
│   ├── App/
│   │   ├── MnemisApp.swift       точка входа: онбординг или RootView
│   │   ├── AppEnvironment.swift  контейнер SwiftData, импорт встроенного словаря
│   │   └── RootView.swift        TabView: Today, Learn, Words, Statistics, Settings
│   ├── Features/                 одна папка — один раздел приложения
│   │   ├── Today/                TodayView: слово дня, Due, Streak
│   │   ├── Learn/                LearnView (сессия), FlashcardView (карточка)
│   │   ├── Words/                WordsView: личный словарь, поиск, добавление
│   │   ├── Statistics/           StatisticsView
│   │   ├── Settings/             SettingsView, LearningSettings (ключи и уровни)
│   │   └── Onboarding/           OnboardingView: первый запуск
│   ├── DesignSystem/             общие визуальные элементы
│   │   ├── Typography.swift      роли шрифтов (SF Pro / SF Mono)
│   │   ├── WordCard.swift        карточка слова
│   │   └── StatTile.swift        плитка «число + подпись»
│   ├── Resources/
│   │   ├── words.json            встроенный словарь (сейчас образец)
│   │   └── Localizable.xcstrings строки EN/RU
│   └── Assets.xcassets
│
├── Packages/MnemisCore/          ядро (Swift Package)
│   ├── Package.swift
│   ├── Sources/MnemisCore/
│   │   ├── Models/               SwiftData: Word, LearningProgress, Review,
│   │   │                         DailyWord, UserExample, UserNote, перечисления
│   │   ├── Persistence/          MnemisStore: схема и создание контейнера
│   │   ├── SpacedRepetition/     SpacedRepetitionEngine (протокол),
│   │   │                         SM2SpacedRepetitionEngine, SchedulingState,
│   │   │                         ReviewService (оценка → прогресс + история)
│   │   ├── Vocabulary/           DailyWordSelector/Service, LearnQueue,
│   │   │                         SearchService, WordImporter, StreakCalculator, DayKey
│   │   └── Dictionary/           протоколы внешних источников, FreeDictionaryAPIService
│   └── Tests/MnemisCoreTests/    тесты ядра (Swift Testing)
│
├── MnemisTests/                  тесты уровня приложения (ресурсы, интеграция)
└── MnemisUITests/                UI-тесты
```

## Правила

1. **Куда класть новый код.** Если код работает без SwiftUI — в `MnemisCore`. Если это экран — в `Features/<Раздел>/`. Если элемент нужен нескольким экранам — в `DesignSystem/`.
2. **View не ходят в сеть.** Внешние API доступны только через протоколы из `MnemisCore/Dictionary` (ABOUT.md, раздел 11).
3. **Алгоритм повторений заменяемый.** Экраны используют `ReviewService`, движок передаётся через протокол `SpacedRepetitionEngine`.
4. **Все модели перечислены в одном месте** — `MnemisStore.models`.
5. **Без `@Attribute(.unique)`**: будущая синхронизация через CloudKit его не поддерживает. Уникальность проверяется в коде.

## Запуск тестов

Ядро (macOS, без симулятора):

```bash
cd Packages/MnemisCore && xcrun swift test
```

Приложение (симулятор):

```bash
xcodebuild test -project Mnemis.xcodeproj -scheme Mnemis -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MnemisTests
```

`xcrun` нужен, чтобы взять Swift из Xcode: другой тулчейн в `PATH` (например, swiftly) может не совпадать с SDK.
