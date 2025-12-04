//  Jonathan Ritchey

import Foundation
import Security

public protocol KeyChainStoreProtocol {
    func save(_ value: String, forKey key: String) throws
    func value(forKey key: String) throws -> String?
    func deleteValue(forKey key: String) throws
}

public final class MockKeyChainStore: KeyChainStoreProtocol {
    var storage: [String: String] = [:]

    public func save(_ value: String, forKey key: String) throws {
        storage[key] = value
    }

    public func value(forKey key: String) throws -> String? {
        storage[key]
    }

    public func deleteValue(forKey key: String) throws {
        storage[key] = nil
    }
}

public enum KeyChainStoreError: Error {
    case stringEncodingFailed
    case stringDecodingFailed
    case unexpectedStatus(OSStatus)
}

public final class SystemKeyChainStore: KeyChainStoreProtocol {

    private let service: String

    /// `service` is used to namespace your app's keychain items.
    public init(service: String = Bundle.main.bundleIdentifier ?? "com.example.app") {
        self.service = service
    }

    // MARK: - KeyChainStoreProtocol

    public func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeyChainStoreError.stringEncodingFailed
        }

        // Base query for this item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Remove any existing item first (simpler than update+add branching)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeyChainStoreError.unexpectedStatus(status)
        }
    }

    public func value(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let string = String(data: data, encoding: .utf8)
            else {
                throw KeyChainStoreError.stringDecodingFailed
            }
            return string

        case errSecItemNotFound:
            return nil

        default:
            throw KeyChainStoreError.unexpectedStatus(status)
        }
    }

    public func deleteValue(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Deleting a non-existent key is not an error
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyChainStoreError.unexpectedStatus(status)
        }
    }
}
