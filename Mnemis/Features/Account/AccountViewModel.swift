import AuthenticationServices
import Foundation
import Observation
import SwiftUI

/// Состояние входа для онбординга, экрана входа и профиля. Сам поток входа живёт в AccountService.
@Observable
@MainActor
final class AccountViewModel {
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    private let account: AccountService

    init(account: AccountService) {
        self.account = account
    }

    var session: AccountSession? { account.session }

    /// Вход через системное окно SwiftUI: адрес возврата ловит схема клиента Google.
    func signInWithGoogle(using session: WebAuthenticationSession) async -> Bool {
        await signInWithGoogle { url, scheme in
            try await session.authenticate(using: url, callback: .customScheme(scheme), additionalHeaderFields: [:])
        }
    }

    /// Возвращает true, если вход завершён. Отмену пользователем не показываем как ошибку.
    func signInWithGoogle(authenticate: (URL, String) async throws -> URL) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await account.signInWithGoogle(authenticate: authenticate)
            errorMessage = nil
            return true
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Обрабатывает ответ системной кнопки Sign in with Apple.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) -> Bool {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return false }
            errorMessage = error.localizedDescription
            return false
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = String(localized: "Apple sign-in didn't complete. Try again.")
                return false
            }
            let name = credential.fullName
                .map { PersonNameComponentsFormatter().string(from: $0) }
                .flatMap { $0.isEmpty ? nil : $0 }
            do {
                try account.signInWithApple(accountID: credential.user, name: name, email: credential.email)
                errorMessage = nil
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
    }

    func signOut() {
        perform { try account.signOut() }
    }

    func deleteAccount() {
        perform { try account.deleteAccount() }
    }

    func setSyncEnabled(_ enabled: Bool) {
        perform { try account.setSyncEnabled(enabled) }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
