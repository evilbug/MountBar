import Foundation
import Security
import CryptoKit

class PasswordManager {
    static let shared = PasswordManager()
    
    private let service = "com.iagoop.MountBar"
    private let rootKeyAccount = "_root_key_v1"
    private let userDefaults = UserDefaults.standard
    private var cachedRootKeyData: Data?
    
    private init() {}
    
    func requestKeychainAccess() {
        _ = ensureRootKey()
    }
    
    func savePassword(for mountID: String, password: String) -> Bool {
        saveEncryptedPassword(for: mountID, password: password)
    }
    
    func getPassword(for mountID: String) -> String? {
        getDecryptedPassword(for: mountID)
    }
    
    func deletePassword(for mountID: String) -> Bool {
        deleteEncryptedPassword(for: mountID)
    }
    
    func saveEncryptedPassword(for mountID: String, password: String) -> Bool {
        guard let rootKey = ensureRootKey(),
              let plaintext = password.data(using: .utf8),
              let encrypted = encrypt(plaintext, using: rootKey) else {
            return false
        }
        return saveKeychainData(account: encryptedPasswordKey(for: mountID), data: encrypted, service: "\(service).passwords")
    }
    
    func getDecryptedPassword(for mountID: String) -> String? {
        if let encrypted = readKeychainData(account: encryptedPasswordKey(for: mountID), service: "\(service).passwords"),
           let rootKey = ensureRootKey(),
           let decrypted = decrypt(encrypted, using: rootKey),
           let password = String(data: decrypted, encoding: .utf8) {
            return password
        }
        
        // Migrate from UserDefaults if exists
        if let legacyData = userDefaults.data(forKey: encryptedPasswordKey(for: mountID)),
           let rootKey = ensureRootKey(),
           let decrypted = decrypt(legacyData, using: rootKey),
           let password = String(data: decrypted, encoding: .utf8) {
            _ = saveEncryptedPassword(for: mountID, password: password)
            userDefaults.removeObject(forKey: encryptedPasswordKey(for: mountID))
            return password
        }
        
        if let legacy = getLegacyKeychainPassword(for: mountID) {
            _ = saveEncryptedPassword(for: mountID, password: legacy)
            _ = deleteLegacyKeychainPassword(for: mountID)
            return legacy
        }
        
        return nil
    }
    
    func deleteEncryptedPassword(for mountID: String) -> Bool {
        _ = deleteKeychainPassword(for: encryptedPasswordKey(for: mountID), service: "\(service).passwords")
        userDefaults.removeObject(forKey: encryptedPasswordKey(for: mountID))
        _ = deleteLegacyKeychainPassword(for: mountID)
        return true
    }
    
    private func encryptedPasswordKey(for mountID: String) -> String {
        "encPwd_\(mountID)"
    }
    
    private func ensureRootKey() -> SymmetricKey? {
        if let cachedRootKeyData {
            return SymmetricKey(data: cachedRootKeyData)
        }
        
        if let existing = readKeychainData(account: rootKeyAccount, service: service) {
            cachedRootKeyData = existing
            return SymmetricKey(data: existing)
        }

        var newKeyData = Data(count: 32)
        let result = newKeyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        guard result == errSecSuccess else {
            return nil
        }
        if saveKeychainData(account: rootKeyAccount, data: newKeyData, service: service) {
            cachedRootKeyData = newKeyData
            return SymmetricKey(data: newKeyData)
        }
        
        return nil
    }
    
    private func saveKeychainData(account: String, data: Data, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func readKeychainData(account: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
    
    private func encrypt(_ plaintext: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key)
            return sealed.combined
        } catch {
            return nil
        }
    }
    
    private func decrypt(_ combined: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealed = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(sealed, using: key)
        } catch {
            return nil
        }
    }
    
    private func getKeychainPassword(for account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }

        return password
    }

    private func deleteKeychainPassword(for account: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    private func getLegacyKeychainPassword(for mountID: String) -> String? {
        return getKeychainPassword(for: mountID, service: service)
    }
    
    private func deleteLegacyKeychainPassword(for mountID: String) -> Bool {
        return deleteKeychainPassword(for: mountID, service: service)
    }
}
