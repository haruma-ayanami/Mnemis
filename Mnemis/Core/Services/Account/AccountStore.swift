import Foundation
import Security

/// Место хранения сессии: Keychain в приложении, память в превью и тестах.
protocol AccountStore {
    func load() throws -> AccountSession?
    func save(_ session: AccountSession) throws
    func clear() throws
}

/// Сессия лежит в Keychain и не попадает в UserDefaults и iCloud Keychain (ABOUT.md, раздел 18).
struct KeychainAccountStore: AccountStore {
    private let service: String

    init(service: String = "haruma.Mnemis.account") {
        self.service = service
    }

    func load() throws -> AccountSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(AccountSession.self, from: data)
    }

    func save(_ session: AccountSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item.merge(attributes) { _, new in new }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "session",
        ]
    }
}

/// Хранилище в памяти: для превью и тестов, на диск ничего не пишет.
final class InMemoryAccountStore: AccountStore {
    private(set) var stored: AccountSession?

    init(session: AccountSession? = nil) {
        stored = session
    }

    func load() throws -> AccountSession? { stored }

    func save(_ session: AccountSession) throws { stored = session }

    func clear() throws { stored = nil }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
    }
}
