import AuthenticationServices
import SwiftUI

/// Вход из Settings, когда аккаунта нет (canvas: Account-Login). Вход необязателен: без него обучение работает полностью.
struct AccountLoginView: View {
    @State private var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    init(container: AppContainer) {
        _viewModel = State(initialValue: AccountViewModel(account: container.account))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            DecorLayer(alignment: .top) {
                DotRings().frame(width: 520, height: 520).opacity(0.3).offset(x: -150, y: -60)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("[ account ]").bracketLabel(AppColor.accent)
                        Text("Sign in")
                            .font(.mnemisTitle).tracking(-0.8)
                            .foregroundStyle(AppColor.ink)
                        Text("Optional. Sync your words, notes and progress between your devices.")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColor.ash)
                    }
                    .padding(.top, 28)

                    VStack(spacing: 12) {
                        GoogleSignInButton(isDisabled: viewModel.isWorking) { signInWithGoogle() }
                        if AccountConfiguration.appleSignInEnabled {
                            AppleSignInButton(isDisabled: viewModel.isWorking) { result in
                                if viewModel.completeAppleSignIn(result) { dismiss() }
                            }
                        }
                        if let message = viewModel.errorMessage {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                        }
                    }
                    .padding(.top, 28)

                    SettingsGroup(title: "What syncs") {
                        syncRow("Words & notes", on: true)
                        syncRow("Progress & reviews", on: true)
                        syncRow("Settings", on: true)
                        SettingsRow(title: "Pronunciation audio") {
                            Text("local only")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(AppColor.smoke)
                        }
                    }
                    .padding(.top, 28)

                    VStack(spacing: 10) {
                        Button("Not now") { dismiss() }
                            .buttonStyle(QuietButtonStyle())
                        Text("signing out keeps your words on this device")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .mnemisNavigationBarHidden()
    }

    private var topBar: some View {
        HStack {
            RoundGlassButton(systemImage: "chevron.left", label: "Back to Settings") { dismiss() }
            Spacer()
            Text("signed out")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColor.smoke)
        }
        .padding(.top, 8)
    }

    private func syncRow(_ title: LocalizedStringKey, on: Bool) -> some View {
        SettingsRow(title: title) {
            Text(on ? "on" : "off")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(on ? AppColor.accent : AppColor.ash)
        }
    }

    private func signInWithGoogle() {
        Task {
            if await viewModel.signInWithGoogle(using: webAuthenticationSession) { dismiss() }
        }
    }
}
