import Foundation
import Observation
import OSLog

/// Вход и выход. Локальные данные от аккаунта не зависят: выход и удаление не трогают словарь и прогресс (ABOUT.md, раздел 18).
@Observable
final class AccountService {
    private(set) var session: AccountSession?

    private let store: AccountStore
    private let googleClientID: String?
    private let api: APIClient

    init(
        store: AccountStore,
        googleClientID: String? = AccountConfiguration.googleClientID,
        api: APIClient = APIClient()
    ) {
        self.store = store
        self.googleClientID = googleClientID
        self.api = api
        do {
            session = try store.load()
        } catch {
            Log.account.error("Session load failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Вход через Apple. Имя и почта приходят только при первом входе, поэтому прежние значения сохраняем.
    func signInWithApple(accountID: String, name: String?, email: String?) throws {
        let previous = session?.accountID == accountID ? session : nil
        try persist(AccountSession(
            provider: .apple,
            accountID: accountID,
            displayName: name ?? previous?.displayName,
            email: email ?? previous?.email,
            syncEnabled: previous?.syncEnabled ?? true
        ))
    }

    /// Вход через Google: код, PKCE и профиль. Окно входа передаёт вызывающий код, поэтому сервис не знает про UI.
    func signInWithGoogle(authenticate: (URL, String) async throws -> URL) async throws {
        guard let clientID = googleClientID else { throw GoogleOAuthError.notConfigured }

        let oauth = GoogleOAuthClient(clientID: clientID, api: api)
        let pkce = PKCECodes.make()
        let state = UUID().uuidString

        let callback = try await authenticate(oauth.authorizationURL(pkce: pkce, state: state), oauth.callbackScheme)
        let code = try oauth.authorizationCode(from: callback, expectedState: state)
        let accessToken = try await oauth.exchangeCode(code, pkce: pkce)
        let profile = try await oauth.profile(accessToken: accessToken)

        let previous = session?.accountID == profile.sub ? session : nil
        try persist(AccountSession(
            provider: .google,
            accountID: profile.sub,
            displayName: profile.name ?? previous?.displayName,
            email: profile.email ?? previous?.email,
            syncEnabled: previous?.syncEnabled ?? true
        ))
    }

    func signOut() throws {
        try store.clear()
        session = nil
    }

    /// Пока сервера нет, удаление убирает только вход на этом устройстве. Серверные данные будут удаляться здесь же.
    func deleteAccount() throws {
        try store.clear()
        session = nil
    }

    func setSyncEnabled(_ enabled: Bool) throws {
        guard var current = session else { return }
        current.syncEnabled = enabled
        try persist(current)
    }

    private func persist(_ newSession: AccountSession) throws {
        try store.save(newSession)
        session = newSession
    }
}
