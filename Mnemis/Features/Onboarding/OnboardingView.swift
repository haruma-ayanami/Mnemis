import AuthenticationServices
import SwiftUI

/// Первый запуск: приветствие, уровень, темп, уведомления (ABOUT.md, раздел 29). Регистрация не нужна.
struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(container: AppContainer) {
        _viewModel = State(initialValue: OnboardingViewModel(container: container))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            switch viewModel.step {
            case .welcome: WelcomeStep(viewModel: viewModel)
            case .level: LevelStep(viewModel: viewModel)
            case .pace: PaceStep(viewModel: viewModel)
            case .account: AccountStep(viewModel: viewModel)
            case .notifications: NotificationsStep(viewModel: viewModel)
            }
        }
        .animation(.smooth(duration: 0.3), value: viewModel.step)
    }
}

// MARK: - Общие части

/// Точки прогресса по трём шагам: 0 — приветствие, 1 — уровень, 2 — темп.
private struct StepDots: View {
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { step in
                Text(step == index ? "●" : "○")
                    .foregroundStyle(step == index ? AppColor.accent : AppColor.faint)
            }
        }
        .font(.system(size: 14, design: .monospaced))
        .accessibilityElement()
        .accessibilityLabel(Text("Step \(index + 1) of 3"))
    }
}

private struct StepHeader: View {
    let counter: String
    let back: () -> Void

    var body: some View {
        HStack {
            RoundGlassButton(systemImage: "chevron.left", label: "Back", action: back)
            Spacer()
            Text(counter)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
        }
    }
}

private struct StepTitle: View {
    let label: LocalizedStringKey
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).bracketLabel(AppColor.accent)
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.9)
                .foregroundStyle(AppColor.ink)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(AppColor.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Шаги

private struct WelcomeStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("mnemis")
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                Spacer()
                HStack(spacing: 4) {
                    Text("EN")
                    Text("→").foregroundStyle(AppColor.accent)
                    Text("RU")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppColor.ash)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .glassCapsule()
            }
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                Text("[ a memory system ]").bracketLabel(AppColor.accent)
                Text("Remember every word you learn.")
                    .font(.system(size: 40, weight: .semibold))
                    .tracking(-1.4)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A few new words a day. Mnemis decides what to review and when.")
                    .font(.system(size: 17))
                    .foregroundStyle(AppColor.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppColor.ink)

            VStack(spacing: 14) {
                Button { viewModel.next() } label: {
                    HStack(spacing: 10) {
                        Text("Get started")
                        Text("→").font(.system(size: 15, design: .monospaced))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("sign-in optional · works offline")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
                StepDots(index: 0)
            }
            .padding(.top, 32)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(AppColor.ink)
        .decor(alignment: .top) {
            ZStack {
                GlowHalo().frame(width: 440, height: 440)
                DotSphere(dotCount: 3200).frame(width: 320, height: 320)
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Text("· every dot is a word you will keep ·")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
                    .padding(.top, 392)
            }
        }
    }
}

private struct LevelStep: View {
    @Bindable var viewModel: OnboardingViewModel

    /// Шкала CEFR от A1 до C1 (ABOUT.md, раздел 13).
    private let info: [LanguageLevel: (name: LocalizedStringKey, hint: LocalizedStringKey)] = [
        .a1: ("Beginner", "First everyday words"),
        .a2: ("Elementary", "Everyday words and phrases"),
        .b1: ("Intermediate", "Work, travel, opinions"),
        .b2: ("Upper-intermediate", "Abstract topics, nuance"),
        .c1: ("Advanced", "Subtle meaning, academic texts"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(counter: "01 / 02") { viewModel.back() }
            StepTitle(label: "[ your level ]", title: "Where do you start?", subtitle: "We pick daily words for this level. You can change it later.")
                .padding(.top, 36)

            VStack(spacing: 10) {
                ForEach(LanguageLevel.allCases) { level in
                    let selected = viewModel.level == level
                    Button { viewModel.level = level } label: {
                        HStack(spacing: 16) {
                            Text(level.rawValue)
                                .font(.system(size: 20, weight: .medium, design: .monospaced))
                                .foregroundStyle(selected ? AppColor.accent : AppColor.ash)
                                .frame(width: 56, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(info[level]?.name ?? "").font(.system(size: 16, weight: .medium))
                                Text(info[level]?.hint ?? "").font(.system(size: 13)).foregroundStyle(AppColor.smoke)
                            }
                            Spacer()
                            Circle()
                                .fill(selected ? AppColor.fill : .clear)
                                .overlay(Circle().stroke(selected ? .clear : AppColor.faint, lineWidth: 1.5))
                                .frame(width: 18, height: 18)
                                .shadow(color: selected ? AppColor.glow.opacity(0.8) : .clear, radius: 7)
                        }
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .background {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(selected ? AppColor.accent.opacity(0.6) : AppColor.hairline, lineWidth: 1)
                        }
                        .modifier(SelectedGlass(selected: selected))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.top, 28)
            .animation(.snappy(duration: 0.15), value: viewModel.level)
            .mnemisHaptic(.selection, trigger: viewModel.level)

            Spacer()
            VStack(spacing: 14) {
                Button { viewModel.next() } label: {
                    HStack(spacing: 10) { Text("Continue"); Text("→").font(.system(size: 15, design: .monospaced)) }
                }
                .buttonStyle(PrimaryButtonStyle())
                StepDots(index: 1)
            }
        }
        .padding(24)
    }
}

private struct SelectedGlass: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        if selected {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            content
        }
    }
}

private struct PaceStep: View {
    @Bindable var viewModel: OnboardingViewModel
    private let presets = [3, 5, 10, 20]

    var body: some View {
        ZStack {
            DecorLayer {
                DotRings().frame(width: 520, height: 520).opacity(0.5).offset(y: -20)
            }

            VStack(spacing: 0) {
                StepHeader(counter: "02 / 02") { viewModel.back() }
                StepTitle(label: "[ daily pace ]", title: "New words per day", subtitle: "Reviews come on top and never count against this limit.")
                    .padding(.top, 36)

                HStack {
                    RoundGlassButton(systemImage: "minus", label: "Fewer words", size: 56) { viewModel.setPace(viewModel.newWordsPerDay - 1) }
                    Spacer()
                    VStack(spacing: 6) {
                        Text(String(format: "%02d", viewModel.newWordsPerDay))
                            .font(.system(size: 88, weight: .medium, design: .monospaced))
                            .tracking(-3.5)
                            .contentTransition(.numericText())
                        Text("≈ \(viewModel.estimatedMinutes) min a day")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                    }
                    Spacer()
                    RoundGlassButton(systemImage: "plus", label: "More words", size: 56) { viewModel.setPace(viewModel.newWordsPerDay + 1) }
                }
                .padding(.top, 40)
                .animation(.snappy, value: viewModel.newWordsPerDay)

                HStack(spacing: 0) {
                    Text(String(repeating: "●", count: viewModel.newWordsPerDay)).foregroundStyle(AppColor.accent)
                    Text(String(repeating: "○", count: 20 - viewModel.newWordsPerDay)).foregroundStyle(AppColor.faint)
                }
                .font(.system(size: 13, design: .monospaced))
                .padding(.top, 14)
                .accessibilityHidden(true)

                HStack(spacing: 4) {
                    ForEach(presets, id: \.self) { value in
                        Button { viewModel.setPace(value) } label: {
                            Text("\(value)")
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(viewModel.newWordsPerDay == value ? AppColor.hairline : .clear, in: .capsule)
                                .foregroundStyle(viewModel.newWordsPerDay == value ? AppColor.ink : AppColor.ash)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(4)
                .glassCapsule()
                .padding(.top, 22)

                Toggle(isOn: $viewModel.remindersOn) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Daily reminder").font(.system(size: 16, weight: .medium))
                        Text(viewModel.remindersOn ? "every day · 09:00" : "off")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                    }
                }
                .toggleStyle(GlowToggleStyle())
                .padding(.horizontal, 20).padding(.vertical, 14)
                .glassCard(cornerRadius: 24)
                .padding(.top, 14)

                Spacer()
                VStack(spacing: 14) {
                    Button { viewModel.next() } label: {
                        HStack(spacing: 10) { Text("Continue"); Text("→").font(.system(size: 15, design: .monospaced)) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    StepDots(index: 2)
                }
            }
            .padding(24)
        }
        .foregroundStyle(AppColor.ink)
    }
}

/// Вход необязателен: Google или Apple, либо пропуск. Без входа обучение работает полностью (ABOUT.md, раздел 18).
private struct AccountStep: View {
    let viewModel: OnboardingViewModel
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(counter: "optional") { viewModel.back() }
            StepTitle(
                label: "[ save progress ]",
                title: "Keep your words safe",
                subtitle: "Sign in to back up your words and sync them between your devices. Learning works fully offline either way."
            )
            .padding(.top, 36)

            VStack(alignment: .leading, spacing: 12) {
                benefit("Backup of words, notes and progress")
                benefit("Restore after reinstalling")
                benefit("Same words on every device")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, 18)
            .glassCard(cornerRadius: 24)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 12) {
                GoogleSignInButton(isDisabled: viewModel.account.isWorking) { signInWithGoogle() }
                if AccountConfiguration.appleSignInEnabled {
                    AppleSignInButton(isDisabled: viewModel.account.isWorking) { result in
                        if viewModel.account.completeAppleSignIn(result) { viewModel.next() }
                    }
                }
                if let message = viewModel.account.errorMessage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
                Button { viewModel.next() } label: {
                    HStack(spacing: 10) { Text("Continue without account"); Text("→").font(.system(size: 15, design: .monospaced)) }
                }
                .buttonStyle(QuietButtonStyle())
                Text("no password stored · you can sign in later in Settings")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppColor.smoke)
            }
        }
        .padding(24)
        .foregroundStyle(AppColor.ink)
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("+")
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(AppColor.accent)
            Text(text).font(.system(size: 15))
        }
    }

    private func signInWithGoogle() {
        Task {
            if await viewModel.account.signInWithGoogle(using: webAuthenticationSession) { viewModel.next() }
        }
    }
}

private struct NotificationsStep: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        ZStack(alignment: .top) {
            DecorLayer(alignment: .top) {
                ZStack {
                    GlowHalo().frame(width: 380, height: 380).offset(y: -20)
                    DotSphere(dotCount: 2000).frame(width: 240, height: 240).opacity(0.85).offset(y: 20)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 10) {
                    SamplePush(kind: "MNEMIS · REVIEW", time: "14:30", title: "14 words are ready", message: "About 6 minutes. Now is the best time.")
                        .scaleEffect(0.94).opacity(0.7)
                    SamplePush(kind: "MNEMIS · WORD OF THE DAY", time: "09:00", title: "accomplish", message: "/əˈkʌmplɪʃ/ · guess the meaning, then tap.")
                }
                .padding(.top, 56)

                Text("[ notifications ]").bracketLabel(AppColor.accent).padding(.top, 40)
                Text("Gentle reminders, only when they help.")
                    .font(.system(size: 32, weight: .semibold)).tracking(-1)
                    .foregroundStyle(AppColor.ink)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(["One word each morning", "A nudge when reviews pile up", "Never more than 2 a day, never at night"], id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("▸").font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(AppColor.accent)
                            Text(LocalizedStringKey(line)).font(.system(size: 15)).foregroundStyle(AppColor.ink)
                        }
                    }
                }
                .padding(.top, 20)

                Spacer()
                VStack(spacing: 8) {
                    Button { Task { await viewModel.allowNotifications() } } label: { Text("Allow notifications") }
                        .buttonStyle(PrimaryButtonStyle())
                    HStack(spacing: 8) {
                        Button { viewModel.finish(notificationsAllowed: false) } label: { Text("Not now") }
                            .buttonStyle(QuietButtonStyle())
                    }
                    Text("change any time in Settings → Notifications")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppColor.smoke)
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 24)
        }
    }
}

/// Пример уведомления в стиле системного: используется на экране запроса разрешения.
struct SamplePush: View {
    let kind: String
    let time: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(light: 0x0A0A0B, dark: 0x0A0A0B))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12)))
                .overlay(DotSphere(dotCount: 220).padding(6))
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(kind).font(.system(size: 10, design: .monospaced)).tracking(1.4).foregroundStyle(AppColor.smoke)
                    Spacer()
                    Text(time).font(.system(size: 12)).foregroundStyle(AppColor.smoke)
                }
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColor.ink)
                Text(message).font(.system(size: 14)).foregroundStyle(AppColor.ash)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 24)
    }
}
