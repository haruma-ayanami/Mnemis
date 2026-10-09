import SwiftUI

/// Первый запуск: уровень и количество новых слов в день (ABOUT.md, раздел 29).
/// Регистрация не нужна. Всё можно поменять позже в Settings.
struct OnboardingView: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(SettingsKey.level) private var levelRaw = LanguageLevel.defaultValue.rawValue
    @AppStorage(SettingsKey.dailyNewWordLimit) private var dailyNewLimit = 5

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Mnemis remembers words for you. Pick a starting point, you can change it any time.")
                        .foregroundStyle(.secondary)
                }

                Section("Level") {
                    Picker("Level", selection: $levelRaw) {
                        ForEach(LanguageLevel.allCases) { level in
                            Text(level.rawValue).tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("New words per day") {
                    Stepper("\(dailyNewLimit) words", value: $dailyNewLimit, in: 1...20)
                }

                Section {
                    Button("Start") {
                        hasOnboarded = true
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Welcome")
        }
    }
}
