import Foundation
import Security

enum KeychainManager {
    private static let serviceName = "com.chargebing.app"
    private static let tokenAccount = "sanctum_auth_token"

    @discardableResult
    static func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }

        deleteToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        print("[KeychainManager] saveToken SecItemAdd status: \(status)")
        if status != errSecSuccess {
            // Fallback to UserDefaults for simulator reliability
            UserDefaults.standard.set(token, forKey: "\(serviceName).\(tokenAccount)")
            print("[KeychainManager] Saved token to UserDefaults fallback")
        }
        return status == errSecSuccess || status == -34018
    }

    static func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data, let token = String(data: data, encoding: .utf8) {
            return token
        }

        // Check fallback from UserDefaults
        if let fallbackToken = UserDefaults.standard.string(forKey: "\(serviceName).\(tokenAccount)"), !fallbackToken.isEmpty {
            return fallbackToken
        }

        return nil
    }

    @discardableResult
    static func deleteToken() -> Bool {
        UserDefaults.standard.removeObject(forKey: "\(serviceName).\(tokenAccount)")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

