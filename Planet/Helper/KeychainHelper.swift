import Foundation
import os

class KeychainHelper: NSObject {
    static let shared = KeychainHelper()

    private var appServiceName: String {
        return String.appGroupName
    }

    private var appICloudSync: Bool {
        return true
    }

    // MARK: - Data

    func saveData(_ data: Data, forKey key: String) throws {
        let saveQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: appServiceName,
            kSecValueData: data,
            kSecUseDataProtectionKeychain: true,
            kSecAttrSynchronizable: appICloudSync
        ] as [String: Any]
        Task(priority: .utility) {
            SecItemDelete(saveQuery as CFDictionary)
            let status = SecItemAdd(saveQuery as CFDictionary, nil)
            if status != errSecSuccess {
                throw PlanetError.KeyManagerSavingKeyError
            }
        }
    }

    func loadData(forKey key: String) throws -> Data {
        let loadQuery: [String: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrService: appServiceName,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrSynchronizable: appICloudSync
        ] as [String: Any]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        guard let data = item as? Data else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        return data
    }

    // MARK: - String

    func saveValue(_ value: String, forKey key: String) throws {
        guard value.count > 0, let data = value.data(using: .utf8) else {
            throw PlanetError.KeyManagerSavingKeyError
        }
        try saveData(data, forKey: key)
    }

    func loadValue(forKey key: String) throws -> String {
        let data = try loadData(forKey: key)
        guard let value = String(data: data, encoding: .utf8) else {
            throw PlanetError.KeyManagerLoadingKeyError
        }
        return value
    }

}
