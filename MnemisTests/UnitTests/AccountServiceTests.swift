import Foundation
import Testing
@testable import Mnemis

/// Вход, выход и хранение сессии. Выход не должен трогать локальные слова (ABOUT.md, раздел 18).
@Suite(.serialized)
@MainActor
struct AccountServiceTests {
    private let googleClientID = "123-abc.apps.googleusercontent.com"

    private func makeService(store: InMemoryAccountStore = InMemoryAccountStore(), googleClientID: String? = nil) -> AccountService {
        AccountService(store: store, googleClientID: googleClientID, api: APIClient(session: GoogleStubProtocol.makeSession()))
    }

    @Test func appleSignInStoresSession() throws {
        let store = InMemoryAccountStore()
        let service = makeService(store: store)

        try service.signInWithApple(accountID: "001.apple", name: "Alex Morgan", email: "alex@example.com")

        #expect(service.session?.provider == .apple)
        #expect(service.session?.displayName == "Alex Morgan")
        #expect(store.stored == service.session)
    }

    @Test func sessionSurvivesRelaunch() throws {
        let store = InMemoryAccountStore()
        try makeService(store: store).signInWithApple(accountID: "001.apple", name: "Alex Morgan", email: nil)

        let relaunched = makeService(store: store)

        #expect(relaunched.session?.accountID == "001.apple")
    }

    @Test func reloginKeepsNameWhenAppleOmitsIt() throws {
        let service = makeService()
        try service.signInWithApple(accountID: "001.apple", name: "Alex Morgan", email: "alex@example.com")

        // Apple присылает имя и почту только при первом входе.
        try service.signInWithApple(accountID: "001.apple", name: nil, email: nil)

        #expect(service.session?.displayName == "Alex Morgan")
        #expect(service.session?.email == "alex@example.com")
    }

    @Test func signOutClearsSessionButKeepsLocalWords() throws {
        let container = try AppContainer.inMemory(clock: TestClock())
        try container.account.signInWithApple(accountID: "001.apple", name: "Alex Morgan", email: nil)
        _ = try container.wordEditor.addWord(lemma: "serendipity", translation: "счастливая случайность")

        try container.account.signOut()

        #expect(container.account.session == nil)
        #expect(try container.words.count() == 1)
    }

    @Test func setSyncEnabledIsStored() throws {
        let store = InMemoryAccountStore()
        let service = makeService(store: store)
        try service.signInWithApple(accountID: "001.apple", name: nil, email: nil)

        try service.setSyncEnabled(false)

        #expect(service.session?.syncEnabled == false)
        #expect(store.stored?.syncEnabled == false)
    }

    @Test func googleSignInWithoutClientIDIsReported() async {
        let service = makeService(googleClientID: nil)

        await #expect(throws: GoogleOAuthError.notConfigured) {
            try await service.signInWithGoogle { _, _ in
                throw GoogleOAuthError.missingCode
            }
        }
        #expect(service.session == nil)
    }

    @Test func googleSignInStoresProfileAfterCodeExchange() async throws {
        GoogleStubProtocol.handler = { request in
            switch request.url?.host {
            case "oauth2.googleapis.com":
                return MockURLProtocol.response(status: 200, body: #"{"access_token":"token-1","expires_in":3600,"token_type":"Bearer"}"#)
            case "openidconnect.googleapis.com":
                return MockURLProtocol.response(status: 200, body: #"{"sub":"1088","name":"Alex Morgan","email":"alex@example.com"}"#)
            default:
                throw URLError(.badURL)
            }
        }
        defer { GoogleStubProtocol.handler = nil }

        let store = InMemoryAccountStore()
        let service = makeService(store: store, googleClientID: googleClientID)

        // Имитируем окно входа: возвращаем код с тем же state, что пришёл в адресе авторизации.
        try await service.signInWithGoogle { authorizationURL, scheme in
            let items = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let state = items.first { $0.name == "state" }?.value ?? ""
            return try #require(URL(string: "\(scheme):/oauth2redirect?code=auth-code&state=\(state)"))
        }

        #expect(service.session == AccountSession(
            provider: .google,
            accountID: "1088",
            displayName: "Alex Morgan",
            email: "alex@example.com",
            syncEnabled: true
        ))
        #expect(store.stored == service.session)
    }

    @Test func googleSignInRejectsForeignState() async throws {
        // Сеть не нужна: ответ с чужим state отбрасывается до обмена кода.
        let service = makeService(googleClientID: googleClientID)

        await #expect(throws: GoogleOAuthError.stateMismatch) {
            try await service.signInWithGoogle { _, scheme in
                try #require(URL(string: "\(scheme):/oauth2redirect?code=auth-code&state=forged"))
            }
        }
        #expect(service.session == nil)
    }
}

/// Подменяет сеть только для входа Google. Отдельный протокол, а не `MockURLProtocol`:
/// у того один общий обработчик, и параллельные наборы тестов мешают друг другу.
private final class GoogleStubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GoogleStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = GoogleStubProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
