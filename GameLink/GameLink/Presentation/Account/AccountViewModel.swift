import Foundation
import Observation

/// Coordinates local account access without retaining passwords after a request.
@MainActor
@Observable
final class AccountViewModel {
  var email = ""
  var password = ""
  var repeatedPassword = ""
  private(set) var identity: AccountIdentity?
  private(set) var failure: AccountError?
  private(set) var isBusy = false
  private(set) var isRestoring = true
  private let registerAccount: RegisterLocalAccountUseCase
  private let signInAccount: SignInLocalAccountUseCase
  private let signOutAccount: SignOutLocalAccountUseCase
  private let restoreSession: RestoreLocalSessionUseCase

  init(
    registerAccount: RegisterLocalAccountUseCase,
    signInAccount: SignInLocalAccountUseCase,
    signOutAccount: SignOutLocalAccountUseCase,
    restoreSession: RestoreLocalSessionUseCase
  ) {
    self.registerAccount = registerAccount
    self.signInAccount = signInAccount
    self.signOutAccount = signOutAccount
    self.restoreSession = restoreSession
  }

  func restore() async {
    guard !isBusy else { return }
    isBusy = true
    isRestoring = true
    failure = nil
    defer {
      isBusy = false
      isRestoring = false
    }
    do { identity = try await restoreSession.execute() } catch { failure = error }
  }

  func submit(registering: Bool) async {
    guard !isBusy else { return }
    failure = nil
    isBusy = true
    defer {
      isBusy = false
      clearSecrets()
    }
    do {
      if registering {
        identity = try await registerAccount.execute(
          email: email, password: password, repeatedPassword: repeatedPassword)
      } else {
        identity = try await signInAccount.execute(email: email, password: password)
      }
    } catch { failure = error }
  }

  func signOut() async {
    guard !isBusy else { return }
    isBusy = true
    failure = nil
    defer { isBusy = false }
    do {
      try await signOutAccount.execute()
      identity = nil
      email = ""
      clearSecrets()
    } catch { failure = error }
  }

  func resetForm() {
    guard !isBusy else { return }
    failure = nil
    clearSecrets()
  }

  private func clearSecrets() {
    password = ""
    repeatedPassword = ""
  }
}
