import SwiftUI

/// Настройки: обучение, уведомления, вид, данные и лицензии.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: SettingsViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Settings").font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
                            .padding(.top, 8)
                        learning
                        notifications
                        appearance
                        data
                        Text("mnemis 0.2 · local-first · sign-in optional")
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.smoke)
                            .frame(maxWidth: .infinity).padding(.top, 4)
                        if let message = viewModel.errorMessage {
                            Text(message).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .mnemisNavigationBarHidden()
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Группы

    private var learning: some View {
        SettingsGroup(title: "Learning") {
            SettingsRow(title: "Language") {
                HStack(spacing: 4) { Text("EN"); Text("→").foregroundStyle(AppColor.accent); Text("RU") }
                    .font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
            }
            SettingsRow(title: "Level") {
                Menu {
                    Picker("Level", selection: Binding(get: { viewModel.settings.proficiencyLevel }, set: { viewModel.setLevel($0) })) {
                        ForEach(LanguageLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.settings.proficiencyLevel.rawValue).font(.system(size: 14, design: .monospaced))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppColor.ash).frame(minHeight: 44)
                }
            }
            SettingsRow(title: "New words per day") {
                HStack(spacing: 12) {
                    Text(String(format: "%02d", viewModel.settings.newWordsPerDay))
                        .font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
                    Stepper("New words per day", value: Binding(
                        get: { viewModel.settings.newWordsPerDay },
                        set: { viewModel.setNewWordsPerDay($0) }
                    ), in: UserSettings.newWordsRange)
                    .labelsHidden()
                }
            }
            Toggle(isOn: Binding(get: { viewModel.settings.phrasesInToday }, set: { viewModel.setPhrasesInToday($0) })) {
                Text("Idioms in Today")
                    .font(.system(size: 16)).foregroundStyle(AppColor.ink)
            }
            .toggleStyle(GlowToggleStyle())
            .padding(.horizontal, 16).frame(minHeight: 54)
        }
    }

    private var notifications: some View {
        SettingsGroup(title: "Notifications & sound") {
            NavigationLink {
                NotificationSettingsView(viewModel: viewModel)
            } label: {
                SettingsRow(title: "Notifications") {
                    HStack(spacing: 8) {
                        Text(viewModel.notificationsRowValue).font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.faint)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
            Toggle("Pronunciation sound", isOn: Binding(get: { viewModel.settings.soundEnabled }, set: { viewModel.setSound($0) }))
                .toggleStyle(GlowToggleStyle())
                .padding(.horizontal, 16).frame(minHeight: 54)
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance").bracketLabel().padding(.leading, 6)
            HStack(spacing: 4) {
                ForEach(ThemePreference.allCases, id: \.self) { theme in
                    let selected = viewModel.settings.preferredTheme == theme
                    Button { viewModel.setTheme(theme) } label: {
                        HStack(spacing: 6) {
                            Text(glyph(theme)).font(.system(size: 13, design: .monospaced))
                            Text(title(theme))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selected ? AppColor.ink : AppColor.ash)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(selected ? AppColor.hairline : .clear, in: .capsule)
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(4)
            .glassCapsule()
        }
    }

    private var data: some View {
        SettingsGroup(title: "Account & data") {
            NavigationLink {
                if container.account.session == nil {
                    AccountLoginView(container: container)
                } else {
                    AccountProfileView(container: container)
                }
            } label: {
                SettingsRow(title: "Account") {
                    HStack(spacing: 8) {
                        Text(viewModel.accountRowValue).font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.faint)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
            ForEach(viewModel.sources) { source in
                DisclosureGroup {
                    Text(source.licenseText)
                        .font(.system(size: 13)).foregroundStyle(AppColor.ash)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name).font(.system(size: 15)).foregroundStyle(AppColor.ink)
                        Text(source.licenseName).font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
    }

    private func glyph(_ theme: ThemePreference) -> String {
        switch theme { case .system: "◐"; case .dark: "●"; case .light: "○" }
    }

    private func title(_ theme: ThemePreference) -> LocalizedStringKey {
        switch theme { case .system: "System"; case .dark: "Dark"; case .light: "Light" }
    }
}

/// Группа строк на стекле с подписью-скобками.
struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).bracketLabel().padding(.leading, 6)
            VStack(spacing: 0) { content }
                .glassCard(cornerRadius: 24)
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16)).foregroundStyle(AppColor.ink)
                if let subtitle {
                    Text(subtitle).font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
