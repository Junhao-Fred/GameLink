import Foundation

/// A player account registered on this device, with a stable ID for its separate notebook.
/// Email identifies local sign-in only; it is not verified or published.
nonisolated struct AccountIdentity: Codable, Equatable, Sendable {
  let id: UUID
  let email: String
}

/// Persists local credentials and one active session without sharing data between accounts.
/// Registration rejects an existing email; signing out retains the account and its notebook.
protocol AccountService: Sendable {
  func restoreSession() async throws -> AccountIdentity?
  func signIn(email: String, password: String) async throws -> AccountIdentity
  func register(email: String, password: String) async throws -> AccountIdentity
  func signOut() async throws
}

/// Validated sign-in details with a trimmed, case-insensitive email address.
/// New passwords require at least 8 characters; all passwords are limited to 1,024 UTF-8 bytes.
/// The password exists only while processing the request and must not be stored as plain text.
nonisolated struct AccountCredentials {
  let email: String
  let password: String

  init(email: String, password: String, registering: Bool) throws(AccountError) {
    let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let parts = address.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."),
      !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
      !address.contains(where: { $0.isWhitespace }), address.count <= 254,
      address.rangeOfCharacter(from: .controlCharacters) == nil
    else { throw .invalidEmail }
    guard !password.isEmpty else { throw .missingPassword }
    guard !registering || password.count >= 8 else { throw .passwordTooShort }
    guard password.utf8.count <= 1024 else { throw .passwordTooLong }
    self.email = address
    self.password = password
  }
}

/// Account failures that the interface can explain without exposing storage details.
nonisolated enum AccountError: LocalizedError, Equatable, Sendable {
  case invalidEmail, passwordTooShort, passwordTooLong, passwordsDiffer, missingPassword
  case invalidCredentials, accountExists, storageUnavailable, accountCreatedSignIn

  var errorDescription: String? {
    switch self {
    case .invalidEmail: "Enter a valid email address."
    case .passwordTooShort: "Use a password with at least 8 characters."
    case .passwordTooLong: "Use a shorter password."
    case .passwordsDiffer: "The passwords do not match."
    case .missingPassword: "Enter your password."
    case .invalidCredentials:
      "The email or password is incorrect, or this account is not registered on this device."
    case .accountExists: "This email is already registered on this device. Please sign in."
    case .storageUnavailable:
      "Account details could not be accessed. Unlock your device and try again."
    case .accountCreatedSignIn:
      "Your account was created, but sign-in could not finish. Please sign in again."
    }
  }
}
