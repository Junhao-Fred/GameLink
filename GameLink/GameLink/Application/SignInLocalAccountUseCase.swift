/// Opens a local account using a normalized email address and its password.
@MainActor
struct SignInLocalAccountUseCase {
  let service: any AccountService

  /// Returns the signed-in identity, or an input, credential or storage failure.
  func execute(email: String, password: String) async throws(AccountError) -> AccountIdentity {
    let credentials = try AccountCredentials(email: email, password: password, registering: false)
    do {
      return try await service.signIn(email: credentials.email, password: credentials.password)
    } catch let failure as AccountError { throw failure } catch { throw .storageUnavailable }
  }
}
