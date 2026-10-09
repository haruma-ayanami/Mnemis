# Mnemis — Architecture and Project Structure

## 1. Архитектурное решение

Для приложения рекомендую **feature-oriented monolith**: один multiplatform Xcode-проект (iPhone, iPad, Mac), единая доменная логика и код, сгруппированный по функциям. Не начинать с десятков Swift Packages, микросервисов или чрезмерно сложной Clean Architecture.

Ключевые правила:

- SwiftUI View отвечает за отображение и пользовательские действия.
- ViewModel координирует экран, но не содержит алгоритм интервального повторения.
- Domain содержит правила обучения и не зависит от SwiftUI, SwiftData, CloudKit и конкретных API.
- SwiftData — локальное хранилище, а не место для бизнес-логики.
- Сетевые источники — необязательное обогащение: приложение работает без интернета.
- SRS, выбор Daily Word, поиск, API и хранение должны быть тестируемыми отдельно.
- Не создавать пустые абстракции «на будущее». Выделять протоколы там, где есть сменяемые реализации, внешний сервис или потребность в тестовых заглушках.

## 2. Рекомендуемая структура проекта

```text
Mnemis/
├── App/
│   ├── MnemisApp.swift
│   ├── AppContainer.swift
│   ├── AppDependencies.swift
│   └── AppRouter.swift
│
├── Core/
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Word.swift
│   │   │   ├── WordMeaning.swift
│   │   │   ├── ExampleSentence.swift
│   │   │   ├── WordProgress.swift
│   │   │   ├── ReviewRecord.swift
│   │   │   ├── DailyWordAssignment.swift
│   │   │   └── UserSettings.swift
│   │   ├── Enums/
│   │   │   ├── LearningStatus.swift
│   │   │   ├── ReviewRating.swift
│   │   │   └── LanguageCode.swift
│   │   └── Rules/
│   │       └── LearningRules.swift
│   │
│   ├── Learning/
│   │   ├── SpacedRepetitionEngine.swift
│   │   ├── DailyWordSelector.swift
│   │   ├── ReviewScheduler.swift
│   │   └── LearningSession.swift
│   │
│   ├── Persistence/
│   │   ├── PersistenceController.swift
│   │   ├── Schema/
│   │   ├── Repositories/
│   │   │   ├── WordRepository.swift
│   │   │   ├── ProgressRepository.swift
│   │   │   ├── ReviewRepository.swift
│   │   │   └── SettingsRepository.swift
│   │   └── Migrations/
│   │
│   ├── Services/
│   │   ├── Dictionary/
│   │   │   ├── DictionaryService.swift
│   │   │   ├── LocalDictionaryProvider.swift
│   │   │   └── FreeDictionaryProvider.swift
│   │   ├── Translation/
│   │   │   ├── TranslationService.swift
│   │   │   └── AppleTranslationProvider.swift
│   │   ├── Examples/
│   │   │   ├── ExampleSentenceService.swift
│   │   │   └── TatoebaProvider.swift
│   │   ├── Pronunciation/
│   │   │   ├── PronunciationService.swift
│   │   │   └── AudioCache.swift
│   │   ├── Notifications/
│   │   │   └── NotificationService.swift
│   │   └── ImportExport/
│   │       ├── ImportService.swift
│   │       └── ExportService.swift
│   │
│   ├── Search/
│   │   └── SearchService.swift
│   ├── Sync/
│   │   ├── SyncService.swift
│   │   └── ConflictPolicy.swift
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   └── APIError.swift
│   ├── DesignSystem/
│   │   ├── Components/
│   │   ├── Typography.swift
│   │   ├── Spacing.swift
│   │   └── AppColors.swift
│   └── Support/
│       ├── Clock.swift
│       └── Logger.swift
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── Today/
│   │   ├── TodayView.swift
│   │   ├── TodayViewModel.swift
│   │   └── Components/
│   ├── Learn/
│   │   ├── LearnView.swift
│   │   ├── LearnViewModel.swift
│   │   ├── FlashcardView.swift
│   │   ├── ReviewViewModel.swift
│   │   └── SessionSummaryView.swift
│   ├── Words/
│   │   ├── WordsView.swift
│   │   ├── WordsViewModel.swift
│   │   ├── WordDetailsView.swift
│   │   ├── AddWordView.swift
│   │   └── EditWordView.swift
│   ├── Statistics/
│   │   ├── StatisticsView.swift
│   │   └── StatisticsViewModel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift
│   └── Shared/
│       ├── EmptyStateView.swift
│       ├── LoadingView.swift
│       └── ErrorStateView.swift
│
├── Platform/
│   ├── iOS/
│   ├── macOS/
│   └── Shared/
│
├── Resources/
│   ├── SeedData/
│   │   ├── words-en-ru.json
│   │   └── seed-manifest.json
│   ├── Localization/
│   │   └── Localizable.xcstrings
│   ├── Licenses/
│   │   └── THIRD_PARTY_NOTICES.md
│   └── Assets.xcassets/
│
└── Tests/
    ├── UnitTests/
    │   ├── SpacedRepetitionEngineTests.swift
    │   ├── DailyWordSelectorTests.swift
    │   ├── SearchServiceTests.swift
    │   ├── PersistenceTests.swift
    │   └── DictionaryProviderTests.swift
    ├── IntegrationTests/
    └── TestSupport/
        ├── TestClock.swift
        ├── Fixtures/
        └── Mocks/
```

### Назначение главных частей

- `App/` — сборка зависимостей и запуск приложения.
- `Core/Domain/` — сущности и правила предметной области.
- `Core/Learning/` — выбор новых слов, расписание и расчёт повторений.
- `Core/Persistence/` — SwiftData, репозитории и миграции.
- `Core/Services/` — API, аудио, уведомления и импорт/экспорт.
- `Features/` — экраны и их ViewModel.
- `Platform/` — только действительно платформенно-зависимый код.
- `Resources/` — встроенный словарь, локализация и лицензии.
- `Tests/` — тесты логики, хранения и пользовательских сценариев.

## 3. Принципиальное решение по модели данных

Не смешивать общую словарную информацию с личным прогрессом пользователя. Слово — это лексическая запись; прогресс — состояние изучения именно этим пользователем.

### Word

```text
id: UUID
lemma: String
normalizedLemma: String
learningLanguage: LanguageCode
translationLanguage: LanguageCode
partOfSpeech: String?
definition: String?
ipa: String?
level: String?
frequencyRank: Int?
sourceID: String?
licenseID: String?
createdAt: Date
updatedAt: Date
```

### WordMeaning

Использовать, если у слова нужно хранить несколько значений. Для совсем простого MVP можно начать с одного перевода в `Word`, но предусмотреть переход к отдельным значениям.

```text
id: UUID
wordID: UUID
translation: String
definition: String?
partOfSpeech: String?
displayOrder: Int
```

### ExampleSentence

```text
id: UUID
wordID: UUID
sentence: String
translation: String?
sourceID: String?
licenseID: String?
isUserCreated: Bool
createdAt: Date
```

Примеры пользователя должны быть отдельными записями и не должны затираться обновлением данных из API.

### WordProgress

```text
id: UUID
wordID: UUID
status: LearningStatus
repetitionCount: Int
correctCount: Int
incorrectCount: Int
difficulty: Double
stability: Double
intervalDays: Double
lastReviewedAt: Date?
nextReviewAt: Date?
introducedAt: Date?
suspendedFromStatus: LearningStatus?
createdAt: Date
updatedAt: Date
```

Для одной локальной учётной записи и языковой пары должно быть не больше одной активной записи прогресса на слово. Если позже появятся профили или несколько языков, ключ прогресса должен учитывать `profileID` и языковую пару.

### ReviewRecord

```text
id: UUID
wordID: UUID
reviewedAt: Date
rating: ReviewRating
previousIntervalDays: Double
scheduledIntervalDays: Double
responseDurationMilliseconds: Int?
sessionID: UUID?
```

Историю попыток не удалять при пересчёте текущего прогресса. Она нужна для статистики и возможной миграции алгоритма.

### DailyWordAssignment

```text
id: UUID
localDayID: String
wordID: UUID
assignedAt: Date
timeZoneIdentifier: String
```

Назначение должно сохраняться. Нельзя выбирать случайное Daily Word при каждом открытии экрана. Уникальность назначения определяется локальным днём и языковой парой/профилем.

### UserSettings

```text
learningLanguage
translationLanguage
proficiencyLevel
newWordsPerDay
dailyReminderEnabled
dailyReminderTime
preferredTheme
soundEnabled
onboardingCompleted
```

## 4. Статусы и переходы

```swift
enum LearningStatus: String, Codable {
    case new
    case learning
    case reviewing
    case remembered
    case known
    case suspended
}
```

- `new` — слово ещё не изучалось.
- `learning` — начальное изучение и короткие интервалы.
- `reviewing` — обычное интервальное повторение.
- `remembered` — интервал достиг заданного порога надёжного запоминания.
- `known` — пользователь вручную отметил слово как известное; обычные повторы не планируются.
- `suspended` — временно исключено из очередей; прежний статус сохраняется для восстановления.

Переходы статусов реализует доменная логика, а не View. Действие «Я это знаю» должно иметь обратимый путь — например, команду «Вернуть в изучение».

## 5. Поток повторения

```text
LearnView
   ↓
ReviewViewModel
   ↓
SubmitReviewUseCase
   ├── получить WordProgress
   ├── передать progress + rating + now в SpacedRepetitionEngine
   ├── создать ReviewRecord
   ├── обновить WordProgress
   └── вернуть результат для следующей карточки
   ↓
обновлённый UI
```

`SpacedRepetitionEngine` не должен обращаться к SwiftData, сети, UI или системным часам. Он получает входные данные и возвращает рассчитанный результат. Время `now` передаётся параметром, чтобы тесты были детерминированными.

Сохранение ReviewRecord и обновлённого WordProgress должно происходить согласованно: нельзя записать историю, но потерять новый прогресс.

## 6. Daily Word и дневные лимиты

`DailyWordSelector` должен выдавать одинаковый результат при одинаковых входных данных.

Порядок отбора:

1. исключить `known` и `suspended`;
2. исключить уже освоенные или уже назначенные слова согласно правилам продукта;
3. учитывать уровень пользователя;
4. предпочитать полезные по частотности слова подходящего уровня;
5. использовать стабильный критерий разрешения равенства.

Daily Word сохраняется до показа. Повторное открытие приложения в тот же локальный день не должно менять слово. Нужно отдельно протестировать смену даты и часового пояса.

Дневной лимит новых слов не должен случайно ограничивать повторения: это разные очереди. Daily Word входит в лимит новых слов.

## 7. API и кэш

```text
Feature / Use Case
        ↓
DictionaryService
        ↓
Provider
  ├── LocalDictionaryProvider
  ├── FreeDictionaryProvider
  └── TatoebaProvider
        ↓
Provider DTO → Mapper → модели приложения
```

Правила интеграции:

- каждый провайдер имеет собственные DTO и парсер;
- JSON-ответы API не сохраняются напрямую как модели SwiftData;
- проверяются HTTP status code, тайм-ауты и ошибки декодирования;
- пустой результат — допустимый исход, а не авария;
- кэшируются успешные ответы;
- пользовательские примеры и заметки не перезаписываются внешними данными;
- сохраняются источник и лицензия встроенных/импортированных данных;
- секретные API-ключи нельзя помещать в клиентское приложение;
- Apple Translation — необязательный адаптер, доступность которого проверяется во время выполнения.

Добавление слова должно работать и с частично заполненными данными: отсутствие аудио или синонимов не блокирует сохранение.

## 8. SwiftData и будущее iCloud

MVP работает с локальной SwiftData. CloudKit добавлять после проверки первой версии.

Перед включением CloudKit отдельно проверить совместимость схемы, отношений, ограничений уникальности и удаления записей. Не считать, что любая локальная схема автоматически готова к синхронизации.

Заранее полезно иметь:

- стабильные UUID;
- `createdAt` и `updatedAt`;
- историю повторений отдельно от текущего прогресса;
- понятную политику конфликтов;
- мягкое удаление/tombstone там, где удаление должно синхронизироваться;
- тесты миграций базы.

`SyncService` — адаптер инфраструктуры. Domain не должен зависеть от CloudKit. Если достаточно iCloud, собственный backend и Google Sign-In не нужны.

## 9. Даты, время и streak

Не вызывать `Date()` по всему проекту. Использовать небольшой `Clock`/`DateProvider`.

- История повторений и `nextReviewAt` хранятся как абсолютные моменты времени.
- Daily Word связывается с локальным днём и явно выбранной временной зоной.
- Streak вычисляется по календарным дням, а не по блокам в 24 часа.
- Изменение часового пояса не должно менять историю.
- Уведомления пересчитываются при изменении настроек.

## 10. Поиск

Для MVP начать с локального поиска по нормализованным полям и примерам. Поиск охватывает слово, перевод, определение, примеры и заметки. Нормализовать регистр и пробелы, но сохранять исходное написание.

Реализация скрыта за `SearchService`, поэтому при росте данных можно сменить внутренний механизм без изменения `WordsView`.

## 11. Ошибки и пустые состояния

Предусмотреть явные состояния для:

- нет слов на повторение;
- нет новых слов подходящего уровня;
- словарь исчерпан;
- API недоступен или вернул пустой результат;
- нет аудио;
- ошибка сохранения;
- база не открылась или миграция не прошла;
- синхронизация недоступна;
- поиск ничего не нашёл.

Ошибка API не должна блокировать ручное добавление слова. Ошибка iCloud не должна лишать пользователя локальных данных.

## 12. iPhone, iPad и Mac

Общие модели, сервисы и логика обучения — общие. Использовать адаптивные SwiftUI-компоновки, а платформенные различия держать в `Platform/`.

- iPhone: основные действия доступны одной рукой.
- iPad: использовать свободное пространство и подходящую навигацию.
- Mac: поддержать клавиатурную навигацию и изменение размера окна.

Не создавать три копии каждого экрана, если достаточно адаптивной View.

## 13. Тесты

В первую очередь тестировать доменную логику, а не только UI.

### SpacedRepetitionEngineTests
- Again/Hard/Good/Easy;
- первый и последующие повторы;
- границы difficulty;
- переходы статусов;
- просроченные повторы;
- фиксированное время.

### DailyWordSelectorTests
- стабильность назначения в течение дня;
- исключение known/suspended;
- дневной лимит;
- исчерпанный словарь;
- смена даты и часового пояса.

### SearchServiceTests
- регистр и пробелы;
- частичное совпадение;
- поиск по переводу, примеру и заметке.

### PersistenceTests
- сохранение и чтение;
- связь прогресса со словом;
- запись истории;
- отсутствие потери пользовательского контента.

### DictionaryProviderTests
- корректный и неполный JSON;
- пустой ответ;
- HTTP-ошибка;
- тайм-аут.

### Критические интеграционные сценарии
- пользователь оценивает карточку, закрывает приложение и после запуска видит обновлённый прогресс;
- слово сохраняется без сети;
- API дополняет слово, не стирая пользовательские примеры;
- пустые состояния отображаются корректно.

## 14. Порядок реализации

### Этап 1 — фундамент
1. Создать multiplatform Xcode-проект.
2. Настроить SwiftData и модели.
3. Определить статусы и правила переходов.
4. Реализовать `SpacedRepetitionEngine`.
5. Написать тесты движка.

### Этап 2 — законченный учебный цикл
1. Загрузить seed-словарь.
2. Реализовать `DailyWordSelector`.
3. Создать Today и Learn.
4. Реализовать карточку и оценки Again/Hard/Good/Easy.
5. Сохранять ReviewRecord и WordProgress.
6. Протестировать весь сценарий.

### Этап 3 — личный словарь
1. Список, поиск и детали слова.
2. Добавление и редактирование.
3. Пользовательские примеры и заметки.
4. Known/Suspended.
5. Пустые состояния.

### Этап 4 — завершение MVP
1. Статистика и streak.
2. Локальные уведомления.
3. Аудио.
4. Локализация и accessibility.
5. Источники, лицензии и атрибуция.

### Этап 5 — обогащение
1. Dictionary API и Tatoeba.
2. Кэш и обработка ошибок.
3. Проверка лицензий и происхождения данных.

### После MVP
- iCloud/CloudKit sync;
- виджет;
- дополнительные режимы тренировки;
- дополнительные языковые пары;
- расширенный поиск.

## 15. Что предотвратит архитектурный долг

- Не помещать SRS в View или ViewModel.
- Не вызывать API из `View.body`.
- Не использовать UserDefaults как основную базу слов и истории.
- Не хранить только текущий статус без истории попыток.
- Не выбирать Daily Word заново при каждом открытии.
- Не перезаписывать пользовательский контент данными API.
- Не привязывать модели приложения к DTO провайдера.
- Не добавлять backend и авторизацию без реальной необходимости.
- Не внедрять сложный DI-контейнер: простого `AppContainer` достаточно.
- Не менять SRS без тестов и решения о судьбе уже накопленного прогресса.
- Не менять схему SwiftData без проверки миграции.
- Архитектурные решения о данных, алгоритме, синхронизации и лицензиях кратко фиксировать в `Docs/Architecture/`.

## 16. Итоговая схема зависимостей

```text
SwiftUI Features
       ↓
ViewModels / Use Cases
       ↓
Domain Rules ───── Learning Engine
       ↓
Repository Interfaces
       ↓
SwiftData Implementations
       ↓
Local Database

Use Cases
  ├── DictionaryService → Providers → External APIs
  ├── PronunciationService → Audio Cache
  ├── NotificationService → UserNotifications
  └── SyncService → CloudKit (после MVP)
```

**Итоговый принцип:** один понятный проект, строгие границы в изменчивых местах и никакой преждевременной сложности. Архитектура должна позволять развивать приложение, не мешая быстро собрать и проверить основной цикл обучения.
