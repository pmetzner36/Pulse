import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case invalidData
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.pulse.app"

    private init() {}

    // MARK: - Token Storage

    func saveTokens(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try save(data: data, forKey: "auth_tokens")
    }

    func loadTokens() throws -> AuthTokens {
        let data = try load(forKey: "auth_tokens")
        return try JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func deleteTokens() throws {
        try delete(forKey: "auth_tokens")
    }

    // MARK: - Generic Keychain Operations

    private func save(data: Data, forKey key: String) throws {
        // Delete existing item first
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    private func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Convenience

    var hasTokens: Bool {
        do {
            _ = try loadTokens()
            return true
        } catch {
            return false
        }
    }
}
