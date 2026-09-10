import Foundation
import Testing

@testable import GameLink

@Suite("Preserving the player's private squad notebook on disk")
@MainActor
struct LocalSquadNotebookRepositoryTests {
  @Test func firstLaunchReturnsAnEmptyNotebookWithoutCreatingSavedData() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    #expect(try repository.loadNotebook() == SquadNotebook())
    #expect(try FileManager.default.contentsOfDirectory(atPath: sandbox.directoryURL.path).isEmpty)
  }

  @Test func productionLocationUsesPrivateApplicationSupportWithoutOpeningSavedData() throws {
    let repository = try LocalSquadNotebookRepository.applicationSupport()
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    #expect(repository.fileURL == support.appending(path: "GameLink/squad-notebook.json"))
  }

  @Test func aNetworkLocationCannotBeUsedForThePrivateNotebook() throws {
    let location = try #require(URL(string: "https://example.invalid/squad-notebook.json"))
    #expect(throws: SquadNotebookStorageError.notebookLocationUnavailable) {
      try LocalSquadNotebookRepository(fileURL: location)
    }
  }

  @Test func reopeningStorageRestoresProfilesIdentifiersContactOrderAndAvoidance() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    var notebook = try SquadFixtures.notebook()
    notebook.contacts.append(
      try SquadFixtures.contact(name: "Sam", server: .europeWest, voice: false))
    notebook.avoidedPlayerIDs = Set(notebook.contacts.map(\.id))
    try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).saveNotebook(notebook)
    let reopened = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    #expect(try reopened.loadNotebook() == notebook)
  }

  @Test(arguments: [PlayDay.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday])
  func reopeningStoragePreservesThePlayersChosenWeekday(_ day: PlayDay) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let notebook = SquadNotebook(ownProfile: try SquadFixtures.profile(day: day))
    try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).saveNotebook(notebook)
    #expect(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook() == notebook)
  }

  @Test(arguments: [PreferredRole.top, .jungle, .middle, .bottom, .support])
  func reopeningStoragePreservesThePlayersChosenRole(_ role: PreferredRole) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let notebook = SquadNotebook(ownProfile: try SquadFixtures.profile(role: role))
    try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).saveNotebook(notebook)
    #expect(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook() == notebook)
  }

  @Test(arguments: [GameServer.oceania, .europeWest, .northAmerica])
  func reopeningStoragePreservesThePlayersChosenServer(_ server: GameServer) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let notebook = SquadNotebook(ownProfile: try SquadFixtures.profile(server: server))
    try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).saveNotebook(notebook)
    #expect(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook() == notebook)
  }

  @Test(arguments: [(0, 30), (1260, 180), (1410, 30)])
  func savedAvailabilityRetainsValidBoundaryTimes(start: Int, duration: Int) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let notebook = SquadNotebook(
      ownProfile: try SquadFixtures.profile(start: start, duration: duration))
    try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).saveNotebook(notebook)
    #expect(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook() == notebook)
  }

  @Test func loadsTheDocumentedVersionOneFormatWithoutDependingOnTheEncoder() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    try sandbox.writeDocument(SquadStorageFixtures.document())
    let notebook = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook()
    let organiser = try #require(notebook.ownProfile)
    let teammate = try #require(notebook.contacts.first)
    #expect(organiser.id.rawValue.uuidString == "11111111-1111-1111-1111-111111111111")
    #expect(organiser.gamerTag == "Alex")
    #expect(organiser.availability.summary == "Friday 19:00-21:00 (Australia/Sydney)")
    #expect(teammate.profile.gamerTag == "Miko")
    #expect(teammate.profile.preferredRole == .support)
    #expect(notebook.avoidedPlayerIDs == [teammate.id])
  }

  @Test func firstSaveCreatesOnlyTheRequiredPrivateNotebookFolders() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let fileURL = sandbox.directoryURL.appending(path: "GameLink/squad-notebook.json")
    let notebook = try SquadFixtures.notebook()
    try LocalSquadNotebookRepository(fileURL: fileURL).saveNotebook(notebook)
    #expect(try LocalSquadNotebookRepository(fileURL: fileURL).loadNotebook() == notebook)
  }

  @Test func replacingSavedDetailsLeavesOneCompleteNotebook() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try repository.saveNotebook(SquadFixtures.notebook())
    var updated = try repository.loadNotebook()
    updated.contacts.append(try SquadFixtures.contact(name: "Taylor"))
    updated.avoidedPlayerIDs = Set(updated.contacts.map(\.id))
    try repository.saveNotebook(updated)
    let savedBytes = try Data(contentsOf: sandbox.fileURL)
    try repository.saveNotebook(updated)
    #expect(try Data(contentsOf: sandbox.fileURL) == savedBytes)
    #expect(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook() == updated)
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: sandbox.directoryURL.path) == [
        "squad-notebook.json"
      ])
  }

  #if targetEnvironment(simulator)
    @Test(
      .disabled(
        "Requires a physical iOS device; this simulator does not expose file protection attributes."
      ))
  #else
    @Test
  #endif
  func savedNotebookRequestsCompleteFileProtectionOnADevice() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try repository.saveNotebook(SquadFixtures.notebook())
    _ = try SaveGamingProfileUseCase(repository: repository).execute(
      SquadFixtures.draft(name: "UpdatedAlex"))
    let attributes = try FileManager.default.attributesOfItem(atPath: sandbox.fileURL.path)
    #expect(attributes[.protectionKey] as? String == FileProtectionType.complete.rawValue)
  }

  @Test func readsNewlySavedDetailsInsteadOfReturningAStaleMemoryCopy() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let reader = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try reader.saveNotebook(SquadFixtures.notebook())
    _ = try reader.loadNotebook()
    let writer = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let changed = try SaveGamingProfileUseCase(repository: writer).execute(
      SquadFixtures.draft(name: "UpdatedAlex"))
    #expect(try reader.loadNotebook().ownProfile == changed)
  }

  @Test func aMissingPreviouslyOpenedNotebookIsNotReplacedWithAnEmptyOne() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let notebook = try SquadFixtures.notebook()
    try repository.saveNotebook(notebook)
    try FileManager.default.removeItem(at: sandbox.fileURL)
    #expect(throws: SquadNotebookStorageError.savedDetailsMissing) { try repository.loadNotebook() }
    #expect(throws: SquadNotebookStorageError.savedDetailsMissing) {
      try repository.saveNotebook(notebook)
    }
    #expect(!FileManager.default.fileExists(atPath: sandbox.fileURL.path))
  }

  @Test func anUnreadableSavedFileIsNotTreatedAsFirstLaunch() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let notebook = try SquadFixtures.notebook()
    try repository.saveNotebook(notebook)
    let savedBytes = try Data(contentsOf: sandbox.fileURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o000], ofItemAtPath: sandbox.fileURL.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o600], ofItemAtPath: sandbox.fileURL.path)
    }
    #expect(throws: SquadNotebookStorageError.savedDetailsUnreadable) {
      try repository.loadNotebook()
    }
    #expect(throws: SquadNotebookStorageError.savedDetailsUnreadable) {
      try repository.saveNotebook(notebook)
    }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o600], ofItemAtPath: sandbox.fileURL.path)
    #expect(try Data(contentsOf: sandbox.fileURL) == savedBytes)
    #expect(try repository.loadNotebook() == notebook)
  }

  @Test func failedAtomicReplacementPreservesSavedDetailsAndAllowsRetry() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let original = try SquadFixtures.notebook()
    try repository.saveNotebook(original)
    let savedBytes = try Data(contentsOf: sandbox.fileURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: sandbox.directoryURL.path)
    let draft = try SquadFixtures.draft(name: "UpdatedAlex")
    #expect(throws: SaveGamingProfileError.profileNotSaved) {
      try SaveGamingProfileUseCase(repository: repository).execute(draft)
    }
    #expect(try Data(contentsOf: sandbox.fileURL) == savedBytes)
    #expect(try repository.loadNotebook() == original)
    #expect(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook() == original)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: sandbox.directoryURL.path)
    let changed = try SaveGamingProfileUseCase(repository: repository).execute(draft)
    #expect(
      try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook().ownProfile
        == changed)
  }

  @Test func aFailedFirstSaveDoesNotCreateAPartialProfile() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o500], ofItemAtPath: sandbox.directoryURL.path)
    #expect(throws: SquadNotebookStorageError.changesNotSaved) {
      try repository.saveNotebook(SquadFixtures.notebook())
    }
    #expect(!FileManager.default.fileExists(atPath: sandbox.fileURL.path))
    #expect(try repository.loadNotebook() == SquadNotebook())
  }
}
