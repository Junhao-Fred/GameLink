import Foundation
import Security

protocol AccountCredentialStore: Sendable {
  nonisolated func read(_ key: String) throws -> Data?
  nonisolated func write(_ data: Data, key: String, replacing: Bool) throws
  nonisolated func remove(_ key: String) throws
}

/// Keeps local credentials on this device and accessible only while it is unlocked.
nonisolated struct AccountKeychainStore: AccountCredentialStore {
  let service: String

  init(service: String = "com.junhaofred.GameLink.local-accounts") {
    self.service = service
  }

  func read(_ key: String) throws -> Data? {
    var request = query(key)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(request as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      throw AccountError.storageUnavailable
    }
    return data
  }

  func write(_ data: Data, key: String, replacing: Bool) throws {
    let request = query(key)
    if replacing {
      let status = SecItemUpdate(request as CFDictionary, [kSecValueData: data] as CFDictionary)
      if status == errSecSuccess { return }
      guard status == errSecItemNotFound else { throw AccountError.storageUnavailable }
    }
    var newItem = request
    newItem[kSecValueData as String] = data
    newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    let status = SecItemAdd(newItem as CFDictionary, nil)
    if status == errSecDuplicateItem { throw AccountError.accountExists }
    guard status == errSecSuccess else { throw AccountError.storageUnavailable }
  }

  func remove(_ key: String) throws {
    let status = SecItemDelete(query(key) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw AccountError.storageUnavailable
    }
  }

  private func query(_ key: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecAttrSynchronizable as String: false,
    ]
  }
}
