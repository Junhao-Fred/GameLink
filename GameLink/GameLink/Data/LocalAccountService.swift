import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Serializes local registration and runs password derivation away from the UI actor.
actor LocalAccountService: AccountService {
  private let store: any AccountCredentialStore
  private let sessionKey = "current-account"

  init(store: any AccountCredentialStore = AccountKeychainStore()) { self.store = store }

  func restoreSession() async throws -> AccountIdentity? {
    guard let data = try store.read(sessionKey) else { return nil }
    let account: AccountIdentity
    do { account = try JSONDecoder().decode(AccountIdentity.self, from: data) } catch {
      throw AccountError.storageUnavailable
    }
    guard let record = try loadRecord(email: account.email), record.identity == account else {
      throw AccountError.storageUnavailable
    }
    return account
  }

  func register(email: String, password: String) async throws -> AccountIdentity {
    let credentials = try AccountCredentials(email: email, password: password, registering: true)
    guard try store.read(accountKey(credentials.email)) == nil else {
      throw AccountError.accountExists
    }
    var salt = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) == errSecSuccess else {
      throw AccountError.storageUnavailable
    }
    let account = AccountIdentity(id: UUID(), email: credentials.email)
    let digest = try LocalPassword.derive(
      credentials.password, salt: salt, rounds: LocalPassword.rounds)
    let record = LocalAccountRecord(
      identity: account, salt: salt, digest: digest, rounds: LocalPassword.rounds)
    try Task.checkCancellation()
    try store.write(
      try JSONEncoder().encode(record), key: accountKey(account.email), replacing: false)
    do { try saveSession(account) } catch { throw AccountError.accountCreatedSignIn }
    return account
  }

  func signIn(email: String, password: String) async throws -> AccountIdentity {
    let credentials = try AccountCredentials(email: email, password: password, registering: false)
    guard let record = try loadRecord(email: credentials.email) else {
      throw AccountError.invalidCredentials
    }
    let digest = try LocalPassword.derive(
      credentials.password, salt: record.salt, rounds: record.rounds)
    guard LocalPassword.equal(digest, record.digest) else { throw AccountError.invalidCredentials }
    try Task.checkCancellation()
    try saveSession(record.identity)
    return record.identity
  }

  func signOut() async throws { try store.remove(sessionKey) }

  private func saveSession(_ account: AccountIdentity) throws {
    try store.write(try JSONEncoder().encode(account), key: sessionKey, replacing: true)
  }

  private func loadRecord(email: String) throws -> LocalAccountRecord? {
    guard let data = try store.read(accountKey(email)) else { return nil }
    let record: LocalAccountRecord
    do { record = try JSONDecoder().decode(LocalAccountRecord.self, from: data) } catch {
      throw AccountError.storageUnavailable
    }
    guard record.version == 1, record.identity.email == email, record.salt.count == 32,
      record.digest.count == 32, (600_000...2_000_000).contains(record.rounds)
    else { throw AccountError.storageUnavailable }
    return record
  }

  private func accountKey(_ email: String) -> String {
    "account-" + SHA256.hash(data: Data(email.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

nonisolated private struct LocalAccountRecord: Codable {
  var version = 1
  let identity: AccountIdentity
  let salt: [UInt8]
  let digest: [UInt8]
  let rounds: UInt32
}

nonisolated enum LocalPassword {
  static let rounds: UInt32 = 600_000

  static func derive(_ password: String, salt: [UInt8], rounds: UInt32) throws -> [UInt8] {
    var result = [UInt8](repeating: 0, count: 32)
    let status = password.withCString { bytes in
      CCKeyDerivationPBKDF(
        CCPBKDFAlgorithm(kCCPBKDF2), bytes, password.utf8.count,
        salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds, &result,
        result.count)
    }
    guard status == kCCSuccess else { throw AccountError.storageUnavailable }
    return result
  }

  static func equal(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    var difference: UInt8 = 0
    for (left, right) in zip(lhs, rhs) { difference |= left ^ right }
    return difference == 0
  }
}
