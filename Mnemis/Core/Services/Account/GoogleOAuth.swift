import CryptoKit
import Foundation

/// Настройки входа. Публичный client ID можно держать в коде: секретов на клиенте нет (ABOUT.md, раздел 18).
enum AccountConfiguration {
    /// iOS client ID из Google Cloud Console (вид `123-abc.apps.googleusercontent.com`).
    /// Публичный: секретом для iOS-клиента не является. Пока не задан, кнопка Google сообщает, что вход недоступен.
    static let googleClientID: String? = "849974356879-rlmp2lfd70ef5qv8v8j0fdu9qns41b2l.apps.googleusercontent.com"

    /// Sign in with Apple требует capability, а она недоступна в бесплатной команде разработчика.
    /// Включайте после подключения платной программы Apple Developer и добавления entitlement `com.apple.developer.applesignin`.
    static let appleSignInEnabled = false
}

enum GoogleOAuthError: LocalizedError, Equatable {
    case notConfigured
    case stateMismatch
    case missingCode
    case providerRejected(String)
    case profileUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured: String(localized: "Google sign-in isn't available in this build yet.")
        case .stateMismatch, .missingCode, .providerRejected, .profileUnavailable:
            String(localized: "Google sign-in didn't complete. Try again.")
        }
    }
}

/// Проверочный код PKCE (RFC 7636): клиент отправляет хеш при входе и исходный код при обмене.
struct PKCECodes: Equatable {
    let verifier: String
    let challenge: String

    init(verifier: String) {
        self.verifier = verifier
        challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    /// 32 случайных байта дают 43 символа: нижняя граница RFC 7636.
    static func make() -> PKCECodes {
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        return PKCECodes(verifier: Data(bytes).base64URLEncodedString())
    }
}

/// OAuth 2.0 Authorization Code с PKCE для iOS-клиента Google. Веб-окно открывает вызывающий код.
struct GoogleOAuthClient {
    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoEndpoint = URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!

    struct Profile: Decodable, Equatable {
        let sub: String
        let name: String?
        let email: String?
    }

    let clientID: String
    let api: APIClient

    init(clientID: String, api: APIClient = APIClient()) {
        self.clientID = clientID
        self.api = api
    }

    /// Google требует схему из client ID в обратном порядке: `com.googleusercontent.apps.<prefix>`.
    var callbackScheme: String {
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }

    var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    func authorizationURL(pkce: PKCECodes, state: String) -> URL {
        var components = URLComponents(url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components?.url ?? Self.authorizationEndpoint
    }

    /// Достаёт код из адреса возврата. Совпадение `state` проверяем, чтобы не принять чужой ответ.
    func authorizationCode(from callback: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let rejected = items.first(where: { $0.name == "error" })?.value {
            throw GoogleOAuthError.providerRejected(rejected)
        }
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            throw GoogleOAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw GoogleOAuthError.missingCode
        }
        return code
    }

    /// Обмен кода на токен доступа. Refresh-токен пока не нужен: синхронизации ещё нет.
    func exchangeCode(_ code: String, pkce: PKCECodes) async throws -> String {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "client_id": clientID,
            "code": code,
            "code_verifier": pkce.verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])

        let data = try await api.send(request)
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokens.accessToken
    }

    func profile(accessToken: String) async throws -> Profile {
        var request = URLRequest(url: Self.userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data = try await api.send(request)
        guard let profile = try? JSONDecoder().decode(Profile.self, from: data) else {
            throw GoogleOAuthError.profileUnavailable
        }
        return profile
    }

    private struct TokenResponse: Decodable {
        let accessToken: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
        }
    }

    private static let formAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    private static func formBody(_ fields: [String: String]) -> Data {
        let body = fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}

private extension Data {
    /// Base64URL без дополнения (RFC 4648, раздел 5), как требует PKCE.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
