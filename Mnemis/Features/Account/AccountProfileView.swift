import SwiftUI

/// Профиль, когда вход выполнен (canvas: Account-Profile). Выход и удаление не трогают локальные слова и прогресс.
struct AccountProfileView: View {
    @State private var viewModel: AccountViewModel
    @State private var confirmsDeletion = false
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer) {
        _viewModel = State(initialValue: AccountViewModel(account: container.account))
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    if let session = viewModel.session {
                        profileCard(session)
                            .padding(.top, 28)
                        syncGroup(session)
                            .padding(.top, 26)
                        accountGroup
                            .padding(.top, 26)
                        Text("words on this device stay after sign-out or deletion.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppColor.smoke)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 26)
                    }
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .mnemisNavigationBarHidden()
        .alert("Delete account?", isPresented: $confirmsDeletion) {
            Button("Delete account", role: .destructive) {
                viewModel.deleteAccount()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your words on this device stay. Only the sign-in is removed.")
        }
    }

    private var topBar: some View {
        HStack {
            RoundGlassButton(systemImage: "chevron.left", label: "Back to Settings") { dismiss() }
            Spacer()
            Text("signed in")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(AppColor.accent)
        }
        .padding(.top, 8)
    }

    private func profileCard(_ session: AccountSession) -> some View {
        HStack(spacing: 16) {
            ZStack {
                GlowHalo().frame(width: 112, height: 112)
                DotSphere(dotCount: 900).frame(width: 72, height: 72)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName ?? session.email ?? session.provider.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                if let email = session.email {
                    Text(email)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(AppColor.smoke)
                        .lineLimit(1)
                }
                Text("via \(session.provider.title)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppColor.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 28)
    }

    private func syncGroup(_ session: AccountSession) -> some View {
        SettingsGroup(title: "Sync") {
            Toggle("Sync words & progress", isOn: Binding(
                get: { session.syncEnabled },
                set: { viewModel.setSyncEnabled($0) }
            ))
            .toggleStyle(GlowToggleStyle())
            .padding(.horizontal, 16).frame(minHeight: 54)

            SettingsRow(title: "Last synced") {
                Text("never")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppColor.ash)
            }
        }
    }

    private var accountGroup: some View {
        SettingsGroup(title: "Account") {
            Button {
                viewModel.signOut()
                dismiss()
            } label: {
                SettingsRow(title: "Sign out") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.faint)
                }
            }
            .buttonStyle(PressScaleStyle())

            Button { confirmsDeletion = true } label: {
                Text("Delete account")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).frame(minHeight: 54)
            }
            .buttonStyle(PressScaleStyle())
        }
    }
}
