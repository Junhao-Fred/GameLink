/// Registers a device-local account after validating and confirming its password.
@MainActor
struct RegisterLocalAccountUseCase {
  let service: any AccountService

  /// Returns the new identity, or a validation, duplicate-account or storage failure.
  func execute(email: String, password: String, repeatedPassword: String) async throws(AccountError)
    -> AccountIdentity
  {
    let credentials = try AccountCredentials(email: email, password: password, registering: true)
    guard password == repeatedPassword else { throw .passwordsDiffer }
    do {
      return try await service.register(email: credentials.email, password: credentials.password)
    } catch let failure as AccountError { throw failure } catch { throw .storageUnavailable }
  }
}
