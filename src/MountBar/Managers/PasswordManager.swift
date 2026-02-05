import Foundation
import Security
import CryptoKit

class PasswordManager {
    static let shared = PasswordManager()
    
    private let service = "com.iagoop.MountBar"
    private let rootKeyAccount = "_root_key_v1"
    private var cachedRootKeyData: Data? {
        didSet {
            if let oldValue = oldValue {
                _ = oldValue.withUnsafeBytes { bytes in
                    memset(UnsafeMutableRawPointer(mutating: bytes.baseAddress), 0, bytes.count)
                }
            }
        }
    }
    
    private init() {}
    
    func requestKeychainAccess() {
        _ = ensureRootKey()
    }
    
    func encryptPassword(_ password: String) -> Data? {
        guard let rootKey = ensureRootKey(),
              let plaintext = password.data(using: .utf8),
              let encrypted = encrypt(plaintext, using: rootKey) else {
            return nil
        }
        return encrypted
    }
    
    func decryptPassword(_ encryptedData: Data) -> String? {
        guard let rootKey = ensureRootKey(),
              let decrypted = decrypt(encryptedData, using: rootKey),
              let password = String(data: decrypted, encoding: .utf8) else {
            return nil
        }
        return password
    }
    
    func getPassword(from mount: SMBMount) -> String? {
        if let encrypted = mount.encryptedPassword {
            return decryptPassword(encrypted)
        }
        
        if let legacy = getLegacyKeychainPassword(for: mount.id.uuidString) {
            return legacy
        }
        
        return nil
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
