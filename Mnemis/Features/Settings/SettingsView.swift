import SwiftUI
import SwiftData
import MnemisCore

/// Настройки (ABOUT.md, раздел 15). Уровень, лимит новых слов и лицензии источников.
struct SettingsView: View {
    @AppStorage(SettingsKey.level) private var levelRaw = LanguageLevel.defaultValue.rawValue
    @AppStorage(SettingsKey.dailyNewWordLimit) private var dailyNewLimit = 5
    @Query private var words: [Word]

    /// Источники встроенного словаря с лицензиями (ABOUT.md, раздел 13).
    private var sources: [String] {
        let pairs = words
            .filter { $0.origin == .builtin }
            .map { "\($0.source) — \($0.license)" }
        return Array(Set(pairs)).sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Learning") {
                    Picker("Level", selection: $levelRaw) {
                        ForEach(LanguageLevel.allCases) { level in
                            Text(level.rawValue).tag(level.rawValue)
                        }
                    }
                    Stepper("New words per day: \(dailyNewLimit)", value: $dailyNewLimit, in: 1...20)
                }

                Section("Sources and licenses") {
                    if sources.isEmpty {
                        Text("No built-in dictionary loaded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sources, id: \.self) { source in
                            Text(source)
                                .font(.callout)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
