/// Ends the saved session without deleting the account or its notebook.
@MainActor
struct SignOutLocalAccountUseCase {
  let service: any AccountService

  /// Clears the active session, or reports a storage failure so the user can retry.
  func execute() async throws(AccountError) {
    do { try await service.signOut() } catch let failure as AccountError { throw failure } catch {
      throw .storageUnavailable
    }
  }
}
