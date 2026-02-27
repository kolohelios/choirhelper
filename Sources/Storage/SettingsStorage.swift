import Foundation
import Models

public protocol SettingsStorageProtocol: Sendable {
    func getAPIKey() async throws -> String?
    func setAPIKey(_ key: String) async throws
    func deleteAPIKey() async throws
    func getUserPartTypes() async -> [PartType]
    func setUserPartTypes(_ types: [PartType]) async
}

public actor SettingsStorage: SettingsStorageProtocol {
    private let keychainService: String
    private let keychainAccount: String
    private let defaults: UserDefaults

    public init(
        keychainService: String = "com.choirhelper.openrouter",
        keychainAccount: String = "api-key",
        defaults: UserDefaults = .standard
    ) {
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
        self.defaults = defaults
    }

    // MARK: - API Key (Keychain)

    public func getAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                let key = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw ChoirHelperError.storageError(
                "Keychain read failed: \(status)"
            )
        }
    }

    public func setAPIKey(_ key: String) throws {
        // Delete existing first
        try? deleteAPIKey()

        guard let data = key.data(using: .utf8) else {
            throw ChoirHelperError.encodingError("Invalid API key encoding")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ChoirHelperError.storageError(
                "Keychain write failed: \(status)"
            )
        }
    }

    public func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ChoirHelperError.storageError(
                "Keychain delete failed: \(status)"
            )
        }
    }

    // MARK: - User Preferences (UserDefaults)

    private static let partTypesKey = "userPartTypes"

    public func getUserPartTypes() -> [PartType] {
        guard let strings = defaults.stringArray(
            forKey: Self.partTypesKey
        ) else {
            return [.tenor]
        }
        return strings.compactMap { PartType(rawValue: $0) }
    }

    public func setUserPartTypes(_ types: [PartType]) {
        let strings = types.map(\.rawValue)
        defaults.set(strings, forKey: Self.partTypesKey)
    }
}
