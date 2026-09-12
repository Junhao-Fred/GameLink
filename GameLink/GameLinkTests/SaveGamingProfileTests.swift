import Testing

@testable import GameLink

@Suite("Saving the organiser's profile")
@MainActor
struct SaveGamingProfileTests {
  @Test func savesATrimmedPlayerName() throws {
    let repository = TestSquadNotebookRepository()
    let profile = try SaveGamingProfileUseCase(repository: repository)
      .execute(SquadFixtures.draft(name: "  Alex  "))
    #expect(profile.gamerTag == "Alex")
    #expect(repository.notebook.ownProfile == profile)
    #expect(repository.successfulSaveCount == 1)
  }

  @Test func editingOwnProfilePreservesIdentityContactsAndAvoidance() throws {
    var notebook = try SquadFixtures.notebook()
    let oldProfile = try #require(notebook.ownProfile)
    let contact = try #require(notebook.contacts.first)
    notebook.avoidedPlayerIDs.insert(contact.id)
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let saved = try SaveGamingProfileUseCase(repository: repository)
      .execute(SquadFixtures.draft(name: "AlexUpdated"))
    #expect(saved.id == oldProfile.id)
    #expect(saved.gamerTag == "AlexUpdated")
    #expect(repository.notebook.contacts == notebook.contacts)
    #expect(repository.notebook.avoidedPlayerIDs == [contact.id])
  }

  @Test(arguments: [
    ("   ", GamingProfileValidationError.missingPlayerName),
    (String(repeating: "A", count: 41), .playerNameTooLong),
    ("Alex\nSupport", .playerNameContainsControlCharacters),
    ("Alex\tSupport", .playerNameContainsControlCharacters),
  ])
  func rejectsInvalidPlayerNamesWithoutReplacingSavedDetails(
    name: String, reason: GamingProfileValidationError
  ) throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let draft = try SquadFixtures.draft(name: name)
    #expect(throws: SaveGamingProfileError.invalidProfile(reason)) {
      try SaveGamingProfileUseCase(repository: repository).execute(draft)
    }
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func acceptsAPlayerNameAtTheFortyCharacterLimit() throws {
    let repository = TestSquadNotebookRepository()
    let saved = try SaveGamingProfileUseCase(repository: repository)
      .execute(SquadFixtures.draft(name: String(repeating: "A", count: 40)))
    #expect(saved.gamerTag.count == 40)
  }

  @Test func preventsOwnProfileFromDuplicatingAnExistingTeammate() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let draft = try SquadFixtures.draft(name: " mIkO ")
    #expect(throws: SaveGamingProfileError.nameUsedByTeammate) {
      try SaveGamingProfileUseCase(repository: repository).execute(draft)
    }
    #expect(repository.notebook == original)
  }

  @Test func failedSaveKeepsThePreviousProfileAndReturnsRecoveryGuidance() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    repository.failsToSave = true
    let draft = try SquadFixtures.draft(name: "NewName")
    #expect(throws: SaveGamingProfileError.profileNotSaved) {
      try SaveGamingProfileUseCase(repository: repository).execute(draft)
    }
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
    #expect(
      SaveGamingProfileError.profileNotSaved.errorDescription?.contains("Try saving again") == true)
  }

  @Test func unreadableNotebookCannotBeReplacedByANewProfile() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    repository.failsToLoad = true
    let draft = try SquadFixtures.draft()
    #expect(throws: SaveGamingProfileError.notebookUnavailable) {
      try SaveGamingProfileUseCase(repository: repository).execute(draft)
    }
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }
}
