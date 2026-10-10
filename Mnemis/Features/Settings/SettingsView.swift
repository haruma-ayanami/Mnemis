import SwiftUI

/// Настройки: профиль, обучение, напоминания, вид и данные. Каждая группа — стеклянная карточка
/// с иконками строк; тексты короткие, значения видны сразу (ABOUT.md, раздел 15).
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
                    VStack(alignment: .leading, spacing: 22) {
                        header.screenEntrance()
                        profileCard.screenEntrance(delay: 0.04)
                        learningGroup.screenEntrance(delay: 0.08)
                        remindersGroup.screenEntrance(delay: 0.12)
                        appearanceGroup.screenEntrance(delay: 0.16)
                        dataGroup.screenEntrance(delay: 0.2)
                        footer
                        if let message = viewModel.errorMessage {
                            Text(message).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .mnemisNavigationBarHidden()
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Шапка и профиль

    private var header: some View {
        Text("Settings")
            .font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
            .padding(.top, 8)
    }

    /// Профиль сверху: вход необязателен, без него всё работает на устройстве.
    private var profileCard: some View {
        NavigationLink {
            if container.account.session == nil {
                AccountLoginView(container: container)
            } else {
                AccountProfileView(container: container)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(AppColor.surface).frame(width: 52, height: 52)
                        .overlay(Circle().stroke(AppColor.hairline))
                    Text(initials)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColor.ink)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(profileName)
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(AppColor.ink)
                    Text(profileDetail)
                        .font(.system(size: 13, design: .monospaced)).foregroundStyle(AppColor.smoke)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.faint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 26)
            .contentShape(.rect(cornerRadius: 26))
        }
        .buttonStyle(PressScaleStyle())
    }

    private var initials: String {
        guard let name = container.account.session?.displayName, let first = name.first else { return "•" }
        return String(first).uppercased()
    }

    private var profileName: String {
        container.account.session?.displayName ?? String(localized: "Learn on this device")
    }

    private var profileDetail: String {
        if let session = container.account.session {
            return "\(session.provider.title) · " + (session.syncEnabled ? String(localized: "sync on") : String(localized: "sync off"))
        }
        return String(localized: "sign in is optional")
    }

    // MARK: - Группы

    private var learningGroup: some View {
        SettingsGroup(title: "Learning") {
            SettingsRow(icon: "character.book.closed", tint: AppColor.accent, title: "Language") {
                Text("EN → RU").font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
            }
            SettingsDivider()
            SettingsRow(icon: "chart.bar", tint: AppColor.accent, title: "Level") {
                Menu {
                    Picker("Level", selection: Binding(get: { viewModel.settings.proficiencyLevel }, set: { viewModel.setLevel($0) })) {
                        ForEach(LanguageLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    valueChip(viewModel.settings.proficiencyLevel.rawValue, menu: true)
                }
            }
            SettingsDivider()
            SettingsRow(icon: "plus.circle", tint: AppColor.accent, title: "New words a day") {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", viewModel.settings.newWordsPerDay))
                        .font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(AppColor.ink)
                    Stepper("New words a day", value: Binding(
                        get: { viewModel.settings.newWordsPerDay },
                        set: { viewModel.setNewWordsPerDay($0) }
                    ), in: UserSettings.newWordsRange)
                    .labelsHidden()
                }
            }
            SettingsDivider()
            SettingsRow(icon: "text.quote", tint: AppColor.accent, title: "Idiom of the day", subtitle: "shown in Today") {
                Toggle(isOn: Binding(get: { viewModel.settings.phrasesInToday }, set: { viewModel.setPhrasesInToday($0) })) { EmptyView() }
                    .toggleStyle(GlowToggleStyle())
            }
        }
    }

    private var remindersGroup: some View {
        SettingsGroup(title: "Reminders & sound") {
            NavigationLink {
                NotificationSettingsView(viewModel: viewModel)
            } label: {
                SettingsRow(icon: "bell", tint: AppColor.fill, title: "Notifications") {
                    HStack(spacing: 8) {
                        Text(viewModel.notificationsRowValue)
                            .font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.faint)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
            SettingsDivider()
            SettingsRow(icon: "speaker.wave.2", tint: AppColor.fill, title: "Pronunciation sound") {
                Toggle(isOn: Binding(get: { viewModel.settings.soundEnabled }, set: { viewModel.setSound($0) })) { EmptyView() }
                    .toggleStyle(GlowToggleStyle())
            }
        }
    }

    private var appearanceGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle("Appearance")
            HStack(spacing: 4) {
                ForEach(ThemePreference.allCases, id: \.self) { theme in
                    let selected = viewModel.settings.preferredTheme == theme
                    Button { withAnimation(Motion.swap) { viewModel.setTheme(theme) } } label: {
                        VStack(spacing: 6) {
                            Image(systemName: symbol(theme))
                                .font(.system(size: 17, weight: .medium))
                            Text(title(theme))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(selected ? AppColor.onPrimary : AppColor.ash)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background {
                            if selected {
                                Capsule().fill(AppColor.primary).matchedGeometryEffect(id: "theme-pill", in: themeSpace)
                            }
                        }
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(4)
            .glassCapsule()
        }
    }

    @Namespace private var themeSpace

    private var dataGroup: some View {
        SettingsGroup(title: "Data") {
            NavigationLink {
                SourcesView(viewModel: viewModel)
            } label: {
                SettingsRow(icon: "doc.text", tint: AppColor.smoke, title: "Sources & licenses") {
                    HStack(spacing: 8) {
                        Text("\(viewModel.sources.count)")
                            .font(.system(size: 14, design: .monospaced)).foregroundStyle(AppColor.ash)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColor.faint)
                    }
                }
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Mnemis 0.2")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(AppColor.smoke)
            Text("local-first · sign-in optional")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(AppColor.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Мелочи

    private func valueChip(_ text: String, menu: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(text).font(.system(size: 14, weight: .medium, design: .monospaced))
            if menu {
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(AppColor.ink)
        .padding(.horizontal, 12).frame(height: 32)
        .background(AppColor.hairline.opacity(0.6), in: .capsule)
    }

    private func symbol(_ theme: ThemePreference) -> String {
        switch theme { case .system: "circle.lefthalf.filled"; case .dark: "moon.fill"; case .light: "sun.max.fill" }
    }

    private func title(_ theme: ThemePreference) -> LocalizedStringKey {
        switch theme { case .system: "System"; case .dark: "Dark"; case .light: "Light" }
    }
}

/// Заголовок группы: моно-подпись в скобках, как во всём приложении.
struct SettingsGroupTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title).bracketLabel().padding(.leading, 6)
    }
}

/// Группа строк на стекле с подписью-скобками.
struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsGroupTitle(title)
            VStack(spacing: 0) { content }
                .glassCard(cornerRadius: 26)
        }
    }
}

/// Тонкий разделитель между строками группы, начинается от текста, а не от иконки.
struct SettingsDivider: View {
    var body: some View {
        Divider().overlay(AppColor.hairline).padding(.leading, 64)
    }
}

/// Строка настроек: цветная иконка, название, подпись и значение справа.
struct SettingsRow<Trailing: View>: View {
    var icon: String?
    var tint: Color = AppColor.smoke
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.onFill)
                    .frame(width: 32, height: 32)
                    .background(tint, in: .rect(cornerRadius: 9))
            }
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
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}

/// Источники данных и их лицензии. Текст лицензии раскрывается по нажатию.
struct SourcesView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sources & licenses").font(.mnemisTitle).tracking(-0.8).foregroundStyle(AppColor.ink)
                        .padding(.top, 8)
                    Text("Words, definitions, translations and idioms come from open dictionaries. Their licenses require attribution.")
                        .font(.system(size: 14)).foregroundStyle(AppColor.ash)
                    SettingsGroup(title: "Sources") {
                        ForEach(Array(viewModel.sources.enumerated()), id: \.element.id) { index, source in
                            if index > 0 { SettingsDivider() }
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
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .mnemisNavigationBarHidden()
    }
}
