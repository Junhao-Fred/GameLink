/// Restores the saved local identity; nil means no account is signed in.
@MainActor
struct RestoreLocalSessionUseCase {
  let service: any AccountService

  /// Returns the saved identity or nil; unreadable storage remains an error.
  func execute() async throws(AccountError) -> AccountIdentity? {
    do { return try await service.restoreSession() } catch let failure as AccountError {
      throw failure
    } catch { throw .storageUnavailable }
  }
}
