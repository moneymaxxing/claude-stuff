import Foundation
import Security

/// Thin wrapper around a generic-password Keychain item, keyed by account
/// name, so the app can store several credentials (Anthropic key, eBay
/// App ID/Cert ID) under one service identifier.
enum KeychainService {
    private static let service = "com.resaleprofit.app"

    enum Account: String {
        case anthropicAPIKey = "anthropic_api_key"
        case ebayAppID = "ebay_app_id"
        case ebayCertID = "ebay_cert_id"
    }

    static func save(_ value: String, for account: Account) {
        let data = Data(value.utf8)
        let query = baseQuery(for: account)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(_ account: Account) -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: Account) {
        SecItemDelete(baseQuery(for: account) as CFDictionary)
    }

    private static func baseQuery(for account: Account) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }

    // MARK: - Convenience accessors

    static func loadAPIKey() -> String? { load(.anthropicAPIKey) }

    static func loadEbayCredentials() -> (appID: String, certID: String)? {
        guard
            let appID = load(.ebayAppID), !appID.isEmpty,
            let certID = load(.ebayCertID), !certID.isEmpty
        else { return nil }
        return (appID, certID)
    }
}
