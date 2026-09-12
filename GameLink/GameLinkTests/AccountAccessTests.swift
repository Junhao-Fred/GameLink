import Foundation
import Testing

@testable import GameLink

@Suite("Local account access and separate workspaces")
@MainActor
struct AccountAccessTests {
  @Test func freshInstallationStartsWithoutAnAccount() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    #expect(try await service.restoreSession() == nil)
  }

  @Test func registrationAndCaseInsensitiveSignInRestoreTheSameAccount() async throws {
    let store = MemoryAccountStore()
    let service = LocalAccountService(store: store)
    let account = try await service.register(
      email: " Fred@example.com ", password: "test-password-123")
    #expect(account.email == "fred@example.com")
    #expect(try await service.restoreSession() == account)
    try await service.signOut()
    #expect(try await service.restoreSession() == nil)
    let reopened = LocalAccountService(store: store)
    #expect(
      try await reopened.signIn(email: "FRED@example.com", password: "test-password-123") == account
    )
  }

  @Test func duplicateRegistrationCannotReplaceAPassword() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    let account = try await service.register(
      email: "fred@example.com", password: "original-password")
    await #expect(throws: AccountError.accountExists) {
      try await service.register(email: "FRED@example.com", password: "replacement-password")
    }
    #expect(
      try await service.signIn(email: "fred@example.com", password: "original-password") == account)
  }

  @Test func wrongPasswordAndMissingAccountCannotCreateASession() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    _ = try await service.register(email: "fred@example.com", password: "original-password")
    try await service.signOut()
    for email in ["fred@example.com", "missing@example.com"] {
      await #expect(throws: AccountError.invalidCredentials) {
        try await service.signIn(email: email, password: "wrong-password")
      }
      #expect(try await service.restoreSession() == nil)
    }
  }

  @Test func credentialsUseDifferentSaltsAndNeverStoreThePassword() async throws {
    let store = MemoryAccountStore()
    let service = LocalAccountService(store: store)
    for email in ["one@example.com", "two@example.com"] {
      _ = try await service.register(email: email, password: "shared-test-password")
    }
    let records = try store.snapshot().filter { $0.key.hasPrefix("account-") }.map {
      try #require(JSONSerialization.jsonObject(with: $0.value) as? [String: Any])
    }
    #expect(records.count == 2)
    #expect(records[0]["salt"] as? [Int] != records[1]["salt"] as? [Int])
    #expect(records[0]["digest"] as? [Int] != records[1]["digest"] as? [Int])
    #expect(
      store.snapshot().values.allSatisfy {
        !String(decoding: $0, as: UTF8.self).contains("shared-test-password")
      })
  }

  @Test func passwordDerivationMatchesKnownPBKDF2SHA256Vector() throws {
    let digest = try LocalPassword.derive("password", salt: Array("salt".utf8), rounds: 1)
    #expect(
      digest.map { String(format: "%02x", $0) }.joined()
        == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
  }

  @Test func keychainCanAddReadUpdateAndRemoveAnIsolatedItem() throws {
    let store = AccountKeychainStore(service: "GameLinkTests.\(UUID().uuidString)")
    defer { try? store.remove("sample") }
    try store.write(Data("first".utf8), key: "sample", replacing: false)
    #expect(try store.read("sample") == Data("first".utf8))
    #expect(throws: AccountError.accountExists) {
      try store.write(Data("duplicate".utf8), key: "sample", replacing: false)
    }
    try store.write(Data("updated".utf8), key: "sample", replacing: true)
    #expect(try store.read("sample") == Data("updated".utf8))
    try store.remove("sample")
    #expect(try store.read("sample") == nil)
  }

  @Test func accountSavedBeforeSessionFailureCanSignInLater() async throws {
    let store = MemoryAccountStore()
    store.rejectsSessionWrites = true
    let service = LocalAccountService(store: store)
    await #expect(throws: AccountError.accountCreatedSignIn) {
      try await service.register(email: "fred@example.com", password: "test-password-123")
    }
    #expect(try await service.restoreSession() == nil)
    store.rejectsSessionWrites = false
    #expect(
      try await service.signIn(email: "fred@example.com", password: "test-password-123").email
        == "fred@example.com")
  }

  @Test func corruptSessionIsNotTreatedAsAnEmptyAccount() async throws {
    let store = MemoryAccountStore()
    try store.write(Data("invalid".utf8), key: "current-account", replacing: true)
    let service = LocalAccountService(store: store)
    await #expect(throws: AccountError.storageUnavailable) { try await service.restoreSession() }
  }

  @Test func restoredSessionOpensTheSameAccount() async {
    let service = TestAccountService()
    service.restoredAccount = service.account
    let model = makeModel(service)
    await model.restore()
    #expect(model.identity == service.account)
    #expect(!model.isRestoring)
  }

  @Test func restorationFailureAllowsRetryWithoutOpeningAWorkspace() async {
    let service = TestAccountService()
    service.failure = .storageUnavailable
    let model = makeModel(service)
    await model.restore()
    #expect(model.identity == nil)
    #expect(model.failure == .storageUnavailable)
    #expect(!model.isRestoring)
    service.failure = nil
    service.restoredAccount = service.account
    await model.restore()
    #expect(model.identity == service.account)
    #expect(model.failure == nil)
  }

  @Test(arguments: ["", "fred", "fred@", "@example.com", "fred@.com", "fred @example.com"])
  func invalidEmailNeverReachesTheService(email: String) async {
    let service = TestAccountService()
    let model = filledModel(service)
    model.email = email
    await model.submit(registering: false)
    #expect(model.failure == .invalidEmail)
    #expect(service.signInCount == 0)
  }

  @Test func registrationRequiresMatchingPasswords() async {
    let service = TestAccountService()
    let model = filledModel(service)
    model.repeatedPassword = "different-password"
    await model.submit(registering: true)
    #expect(model.failure == .passwordsDiffer)
    #expect(service.registerCount == 0)
  }

  @Test func shortRegistrationPasswordNeverReachesTheService() async {
    let service = TestAccountService()
    let model = filledModel(service)
    model.password = "short"
    model.repeatedPassword = "short"
    await model.submit(registering: true)
    #expect(model.failure == .passwordTooShort)
    #expect(service.registerCount == 0)
  }

  @Test func registrationOpensTheNewAccountAndClearsPasswords() async {
    let service = TestAccountService()
    let model = filledModel(service)
    await model.submit(registering: true)
    #expect(model.identity == service.account)
    #expect(model.password.isEmpty && model.repeatedPassword.isEmpty)
    #expect(!model.isBusy)
  }

  @Test func failedSignInDoesNotOpenAWorkspaceOrKeepThePassword() async {
    let service = TestAccountService()
    service.failure = .invalidCredentials
    let model = filledModel(service)
    await model.submit(registering: false)
    #expect(model.identity == nil)
    #expect(model.failure == .invalidCredentials)
    #expect(model.password.isEmpty)
    #expect(!model.isBusy)
  }

  @Test func concurrentTapsSendOneSignInRequest() async {
    let service = TestAccountService()
    service.holdsSignIn = true
    let model = filledModel(service)
    let first = Task { await model.submit(registering: false) }
    await service.waitUntilSignInStarts()
    await model.submit(registering: false)
    #expect(service.signInCount == 1)
    service.finishSignIn()
    await first.value
    #expect(model.identity == service.account)
    #expect(!model.isBusy)
  }

  @Test func signingOutClearsAccountAndSensitiveInput() async {
    let service = TestAccountService()
    let model = filledModel(service)
    await model.submit(registering: false)
    model.password = "temporary-input"
    await model.signOut()
    #expect(model.identity == nil)
    #expect(model.email.isEmpty)
    #expect(model.password.isEmpty)
    #expect(service.signOutCount == 1)
  }

  @Test func failedSignOutKeepsTheWorkspaceAvailableForRetry() async {
    let service = TestAccountService()
    let model = filledModel(service)
    await model.submit(registering: false)
    service.failure = .storageUnavailable
    await model.signOut()
    #expect(model.identity == service.account)
    #expect(model.failure == .storageUnavailable)
    #expect(!model.isBusy)
  }

  @Test func accountsAndGuestCannotReadEachOthersNotebooks() throws {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let firstID = UUID()
    let first = try LocalSquadNotebookRepository(
      fileURL: LocalSquadNotebookRepository.notebookURL(in: folder, accountID: firstID))
    let second = try LocalSquadNotebookRepository(
      fileURL: LocalSquadNotebookRepository.notebookURL(in: folder, accountID: UUID()))
    let guest = try LocalSquadNotebookRepository(
      fileURL: LocalSquadNotebookRepository.notebookURL(in: folder, accountID: nil))
    let profile = try SquadFixtures.profile()
    try first.saveNotebook(SquadNotebook(ownProfile: profile))
    #expect(try second.loadNotebook().ownProfile == nil)
    #expect(try guest.loadNotebook().ownProfile == nil)
    let reopened = try LocalSquadNotebookRepository(
      fileURL: LocalSquadNotebookRepository.notebookURL(in: folder, accountID: firstID))
    #expect(try reopened.loadNotebook().ownProfile == profile)
    #expect(guest.fileURL == folder.appending(path: "GameLink/squad-notebook.json"))
  }

  @Test func registerUseCaseCreatesANormalizedLocalSession() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    let account = try await RegisterLocalAccountUseCase(service: service).execute(
      email: " Fred@example.com ", password: "test-password", repeatedPassword: "test-password")
    #expect(account.email == "fred@example.com")
    #expect(try await service.restoreSession() == account)
  }

  @Test func registerUseCaseRejectsDuplicateEmailWithoutReplacingTheAccount() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    let useCase = RegisterLocalAccountUseCase(service: service)
    let original = try await useCase.execute(
      email: "fred@example.com", password: "original-password",
      repeatedPassword: "original-password")
    await #expect(throws: AccountError.accountExists) {
      try await useCase.execute(
        email: "FRED@example.com", password: "new-password", repeatedPassword: "new-password")
    }
    #expect(
      try await service.signIn(email: original.email, password: "original-password") == original)
  }

  @Test func signInUseCaseReopensTheRegisteredIdentity() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    let original = try await service.register(email: "fred@example.com", password: "test-password")
    try await service.signOut()
    let account = try await SignInLocalAccountUseCase(service: service).execute(
      email: " FRED@example.com ", password: "test-password")
    #expect(account == original)
    #expect(try await service.restoreSession() == original)
  }

  @Test func signInUseCaseRejectsWrongPasswordWithoutOpeningASession() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    _ = try await service.register(email: "fred@example.com", password: "test-password")
    try await service.signOut()
    await #expect(throws: AccountError.invalidCredentials) {
      try await SignInLocalAccountUseCase(service: service).execute(
        email: "fred@example.com", password: "wrong-password")
    }
    #expect(try await service.restoreSession() == nil)
  }

  @Test func signOutUseCaseEndsTheSessionButKeepsTheAccount() async throws {
    let service = LocalAccountService(store: MemoryAccountStore())
    let account = try await service.register(email: "fred@example.com", password: "test-password")
    try await SignOutLocalAccountUseCase(service: service).execute()
    #expect(try await service.restoreSession() == nil)
    #expect(try await service.signIn(email: account.email, password: "test-password") == account)
  }

  @Test func signOutUseCaseReportsFailureAndAllowsRetry() async throws {
    let service = TestAccountService()
    service.failure = .storageUnavailable
    let useCase = SignOutLocalAccountUseCase(service: service)
    await #expect(throws: AccountError.storageUnavailable) { try await useCase.execute() }
    service.failure = nil
    try await useCase.execute()
    #expect(service.signOutCount == 2)
  }

  @Test func restoreUseCaseReopensSavedIdentityAndAcceptsNoSession() async throws {
    let store = MemoryAccountStore()
    let service = LocalAccountService(store: store)
    let useCase = RestoreLocalSessionUseCase(service: LocalAccountService(store: store))
    #expect(try await useCase.execute() == nil)
    let account = try await service.register(email: "fred@example.com", password: "test-password")
    #expect(try await useCase.execute() == account)
  }

  @Test func restoreUseCaseReportsCorruptSessionWithoutDeletingIt() async throws {
    let store = MemoryAccountStore()
    let corruptData = Data("invalid".utf8)
    try store.write(corruptData, key: "current-account", replacing: true)
    let useCase = RestoreLocalSessionUseCase(service: LocalAccountService(store: store))
    await #expect(throws: AccountError.storageUnavailable) { try await useCase.execute() }
    #expect(try store.read("current-account") == corruptData)
  }

  private func makeModel(_ service: TestAccountService) -> AccountViewModel {
    AccountViewModel(
      registerAccount: RegisterLocalAccountUseCase(service: service),
      signInAccount: SignInLocalAccountUseCase(service: service),
      signOutAccount: SignOutLocalAccountUseCase(service: service),
      restoreSession: RestoreLocalSessionUseCase(service: service))
  }

  private func filledModel(_ service: TestAccountService) -> AccountViewModel {
    let model = makeModel(service)
    model.email = " fred@example.com "
    model.password = "test-password-123"
    model.repeatedPassword = "test-password-123"
    return model
  }
}

@MainActor
private final class TestAccountService: AccountService {
  let account = AccountIdentity(id: UUID(), email: "fred@example.com")
  var restoredAccount: AccountIdentity?
  var failure: AccountError?
  var signInCount = 0
  var registerCount = 0
  var signOutCount = 0
  var holdsSignIn = false
  private var signInContinuation: CheckedContinuation<Void, Never>?
  private var startedContinuation: CheckedContinuation<Void, Never>?

  func restoreSession() async throws -> AccountIdentity? {
    if let failure { throw failure }
    return restoredAccount
  }

  func signIn(email: String, password: String) async throws -> AccountIdentity {
    signInCount += 1
    if holdsSignIn {
      await withCheckedContinuation { continuation in
        signInContinuation = continuation
        startedContinuation?.resume()
        startedContinuation = nil
      }
    }
    if let failure { throw failure }
    return account
  }

  func waitUntilSignInStarts() async {
    if signInContinuation != nil { return }
    await withCheckedContinuation { startedContinuation = $0 }
  }

  func finishSignIn() {
    signInContinuation?.resume()
    signInContinuation = nil
  }

  func register(email: String, password: String) async throws -> AccountIdentity {
    registerCount += 1
    if let failure { throw failure }
    return account
  }

  func signOut() async throws {
    signOutCount += 1
    if let failure { throw failure }
  }
}

nonisolated private final class MemoryAccountStore: AccountCredentialStore, @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: Data] = [:]
  private var failsSessionWrites = false

  var rejectsSessionWrites: Bool {
    get { lock.withLock { failsSessionWrites } }
    set { lock.withLock { failsSessionWrites = newValue } }
  }

  func snapshot() -> [String: Data] { lock.withLock { values } }
  func read(_ key: String) throws -> Data? { lock.withLock { values[key] } }

  func write(_ data: Data, key: String, replacing: Bool) throws {
    try lock.withLock {
      if failsSessionWrites && key == "current-account" { throw AccountError.storageUnavailable }
      if !replacing && values[key] != nil { throw AccountError.accountExists }
      values[key] = data
    }
  }

  func remove(_ key: String) throws { lock.withLock { values[key] = nil } }
}
