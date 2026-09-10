import Foundation
import Testing

@testable import GameLink

@Suite("Refusing to replace damaged or incompatible squad details")
@MainActor
struct SavedSquadNotebookValidationTests {
  @Test(arguments: ["", "{", "null", "[]", "{\"schemaVersion\":1}", "{\"schemaVersion\":\"1\"}"])
  func malformedSavedDetailsRemainUntouchedInsteadOfBecomingAnEmptyDirectory(_ json: String) throws
  {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let original = Data(json.utf8)
    try original.write(to: sandbox.fileURL)
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    #expect(throws: SquadNotebookStorageError.savedDetailsInvalid) { try repository.loadNotebook() }
    #expect(throws: SquadNotebookStorageError.savedDetailsInvalid) {
      try repository.saveNotebook(SquadFixtures.notebook())
    }
    #expect(throws: SaveGamingProfileError.notebookUnavailable) {
      try SaveGamingProfileUseCase(repository: repository).execute(SquadFixtures.draft())
    }
    #expect(try Data(contentsOf: sandbox.fileURL) == original)
  }

  @Test(arguments: [-1, 0, 2, 999])
  func unsupportedFormatsAreRecognisedBeforeInterpretingOrReplacingTheirContents(_ version: Int)
    throws
  {
    try expectSavedDocumentRejected(
      ["schemaVersion": version, "futureProfileFormat": ["nickname": "Alex"]],
      reason: .unsupportedStorageVersion)
  }

  @Test(arguments: [
    ("gamerTag", ""), ("gamerTag", "  "), ("gamerTag", " Alex "),
    ("gamerTag", String(repeating: "A", count: 41)), ("gamerTag", "Alex\nSupport"),
    ("server", "Unknown Server"), ("preferredRole", "Unknown Role"),
    ("playerID", "not-an-identifier"),
  ])
  func invalidSavedProfilesCannotBypassThePlayerRules(field: String, value: String) throws {
    var document = SquadStorageFixtures.document()
    var profile = SquadStorageFixtures.profileDocument()
    profile[field] = value
    document["ownProfile"] = profile
    try expectSavedDocumentRejected(document)
  }

  @Test(arguments: [
    ("startMinute", -1), ("startMinute", 1440), ("startMinute", Int.max),
    ("startMinute", 1380), ("durationMinutes", 29), ("durationMinutes", 181),
    ("durationMinutes", Int.max),
  ])
  func invalidSavedAvailabilityCannotBypassTimeBoundaries(field: String, value: Int) throws {
    var document = SquadStorageFixtures.document()
    var profile = SquadStorageFixtures.profileDocument()
    var availability = try #require(profile["availability"] as? [String: Any])
    availability[field] = value
    profile["availability"] = availability
    document["ownProfile"] = profile
    try expectSavedDocumentRejected(document)
  }

  @Test(arguments: [("day", "Someday"), ("timeZoneIdentifier", "UTC")])
  func savedAvailabilityCannotSilentlyChangeItsDayOrTimeZone(field: String, value: String) throws {
    var document = SquadStorageFixtures.document()
    var profile = SquadStorageFixtures.profileDocument()
    var availability = try #require(profile["availability"] as? [String: Any])
    availability[field] = value
    profile["availability"] = availability
    document["ownProfile"] = profile
    try expectSavedDocumentRejected(document)
  }

  @Test(arguments: [
    "playerID", "gamerTag", "server", "preferredRole", "availability", "usesVoiceChat",
  ])
  func incompleteSavedProfilesAreNotFilledWithInventedDefaults(_ field: String) throws {
    var document = SquadStorageFixtures.document()
    var profile = SquadStorageFixtures.profileDocument()
    profile.removeValue(forKey: field)
    document["ownProfile"] = profile
    try expectSavedDocumentRejected(document)
  }

  @Test func invalidTeammateDetailsAreRejectedAsStrictlyAsTheOrganisersProfile() throws {
    var document = SquadStorageFixtures.document()
    document["contacts"] = [
      SquadStorageFixtures.profileDocument(
        id: SquadStorageFixtures.teammateID, name: "", role: "Support")
    ]
    try expectSavedDocumentRejected(document)
  }

  @Test func teammateDetailsCannotBeLoadedWithoutTheOrganisersProfile() throws {
    var document = SquadStorageFixtures.document()
    document.removeValue(forKey: "ownProfile")
    try expectSavedDocumentRejected(document)
  }

  @Test func multipleSavedTeammatesCannotShareOneLocalIdentifier() throws {
    var document = SquadStorageFixtures.document()
    document["contacts"] = [
      SquadStorageFixtures.profileDocument(id: SquadStorageFixtures.teammateID, name: "Miko"),
      SquadStorageFixtures.profileDocument(id: SquadStorageFixtures.teammateID, name: "Taylor"),
    ]
    try expectSavedDocumentRejected(document)
  }

  @Test func theOrganisersIdentifierCannotAlsoBelongToASavedTeammate() throws {
    var document = SquadStorageFixtures.document()
    document["contacts"] = [SquadStorageFixtures.profileDocument(name: "Miko")]
    document["avoidedPlayerIDs"] = [] as [String]
    try expectSavedDocumentRejected(document)
  }

  @Test func duplicateSavedTeammateNamesAreRejectedIgnoringCaseOnTheSameServer() throws {
    var document = SquadStorageFixtures.document()
    document["contacts"] = [
      SquadStorageFixtures.profileDocument(id: SquadStorageFixtures.teammateID, name: "Miko"),
      SquadStorageFixtures.profileDocument(
        id: "33333333-3333-3333-3333-333333333333", name: "mIkO"),
    ]
    try expectSavedDocumentRejected(document)
  }

  @Test func theOrganisersNameAndServerCannotAlsoIdentifyASavedTeammate() throws {
    var document = SquadStorageFixtures.document()
    document["contacts"] = [
      SquadStorageFixtures.profileDocument(id: SquadStorageFixtures.teammateID, name: "aLEX")
    ]
    try expectSavedDocumentRejected(document)
  }

  @Test(arguments: [
    ["33333333-3333-3333-3333-333333333333"],
    ["11111111-1111-1111-1111-111111111111"],
    ["22222222-2222-2222-2222-222222222222", "22222222-2222-2222-2222-222222222222"],
  ])
  func invalidAvoidanceCannotBeSilentlyDiscardedOrReassigned(_ identifiers: [String]) throws {
    var document = SquadStorageFixtures.document()
    document["avoidedPlayerIDs"] = identifiers
    try expectSavedDocumentRejected(document)
  }

  @Test func malformedDataFoundAfterAValidReadStillBlocksReplacement() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let notebook = try SquadFixtures.notebook()
    try repository.saveNotebook(notebook)
    let damaged = Data("{\"schemaVersion\":".utf8)
    try damaged.write(to: sandbox.fileURL)
    #expect(throws: SquadNotebookStorageError.savedDetailsInvalid) {
      try repository.saveNotebook(notebook)
    }
    #expect(try Data(contentsOf: sandbox.fileURL) == damaged)
  }

  @Test func invalidIncomingAvoidanceCannotReplaceAValidSavedNotebook() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let notebook = try SquadFixtures.notebook()
    try repository.saveNotebook(notebook)
    let original = try Data(contentsOf: sandbox.fileURL)
    var invalid = notebook
    invalid.avoidedPlayerIDs = [PlayerIdentifier()]
    #expect(throws: SquadNotebookStorageError.savedDetailsInvalid) {
      try repository.saveNotebook(invalid)
    }
    #expect(try Data(contentsOf: sandbox.fileURL) == original)
    #expect(try repository.loadNotebook() == notebook)
  }

  private func expectSavedDocumentRejected(
    _ document: [String: Any], reason: SquadNotebookStorageError = .savedDetailsInvalid
  ) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let original = try sandbox.writeDocument(document)
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    #expect(throws: reason) { try repository.loadNotebook() }
    #expect(throws: reason) { try repository.saveNotebook(SquadFixtures.notebook()) }
    #expect(try Data(contentsOf: sandbox.fileURL) == original)
  }
}
