import AuthenticationServices
import SwiftUI

/// «Continue with Google»: белая капсула с логотипом. В светлой теме с тонкой обводкой (canvas: Onboarding-Account).
struct GoogleSignInButton: View {
    var isDisabled = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Continue with Google")
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color(light: 0x1F1F1F, dark: 0x1F1F1F))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color(light: 0xFFFFFF, dark: 0xFFFFFF), in: .capsule)
            .overlay(Capsule().stroke(Color.black.opacity(colorScheme == .dark ? 0 : 0.14)))
        }
        .buttonStyle(PressScaleStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

/// Системная кнопка Sign in with Apple. По правилам App Store она обязательна рядом с Google (ABOUT.md, раздел 18).
struct AppleSignInButton: View {
    var isDisabled = false
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            onCompletion(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(maxWidth: .infinity, minHeight: 56)
        .clipShape(.capsule)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}
