// File: KeychainHelper.swift
// Purpose: Defines KeychainHelper component for Cantinarr

import Foundation

#if canImport(Security)
import Security

/// Wrapper around the Security framework for storing small secrets.
class KeychainHelper {
    /// Save sensitive data (e.g., API keys) to the Keychain.
    /// Data is stored with `kSecAttrAccessibleAfterFirstUnlock` so it remains
    /// available after a restart once the user has unlocked the device.
    static func save(key: String, data: Data) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Explicit accessibility level for stronger security.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        // Remove any existing item before adding new data.
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil)
    }

    /// Retrieve data for a given key from the Keychain.
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == noErr, let data = dataTypeRef as? Data {
            return data
        }
        return nil
    }

    /// Remove a value from the Keychain.
    @discardableResult
    static func delete(key: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        return SecItemDelete(query as CFDictionary)
    }
}

#else

/// Stubbed helper when Security is unavailable.
/// Returns `0` for save/delete and always yields `nil` for load.
typealias OSStatus = Int32

class KeychainHelper {
    @discardableResult
    static func save(key: String, data: Data) -> OSStatus { 0 }
    static func load(key: String) -> Data? { nil }
    @discardableResult
    static func delete(key: String) -> OSStatus { 0 }
}

#endif
