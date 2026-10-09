import Foundation

/// Провайдер входа. Названия брендов не переводятся.
enum AccountProvider: String, Codable, CaseIterable, Sendable {
    case google
    case apple

    var title: String {
        switch self {
        case .google: "Google"
        case .apple: "Apple"
        }
    }
}

/// Вход на этом устройстве: профиль и флаг синхронизации. Токены сюда не входят: они понадобятся вместе с сервером (ABOUT.md, раздел 18).
struct AccountSession: Codable, Equatable, Sendable {
    let provider: AccountProvider
    /// Стабильный идентификатор у провайдера: `sub` у Google, user ID у Apple.
    let accountID: String
    var displayName: String?
    var email: String?
    var syncEnabled: Bool
}
