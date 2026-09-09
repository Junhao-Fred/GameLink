import Testing

@testable import GameLink

@Suite("Maintaining a private teammate directory")
@MainActor
struct SaveTeammateContactTests {
  @Test func recordsATeammateAfterPermissionIsConfirmed() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let contact = try SaveTeammateContactUseCase(repository: repository)
      .execute(SquadFixtures.draft(name: "Jade", role: .support), permissionConfirmed: true)
    #expect(repository.notebook.contacts.count == 2)
    #expect(repository.notebook.contacts.last == contact)
  }

  @Test func refusesToRecordDetailsWithoutPermission() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let draft = try SquadFixtures.draft(name: "Jade")
    #expect(throws: SaveTeammateContactError.permissionRequired) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: false)
    }
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func requiresOwnProfileBeforeRecordingTeammates() throws {
    let repository = TestSquadNotebookRepository()
    let draft = try SquadFixtures.draft(name: "Jade")
    #expect(throws: SaveTeammateContactError.ownProfileRequired) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: true)
    }
  }

  @Test func rejectsEmptyTeammateName() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let draft = try SquadFixtures.draft(name: "")
    #expect(throws: SaveTeammateContactError.invalidProfile(.missingPlayerName)) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: true)
    }
    #expect(repository.notebook.contacts.count == 1)
  }

  @Test func rejectsDuplicateTeammatesIgnoringNameCaseAndOuterSpaces() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let draft = try SquadFixtures.draft(name: " mIkO ")
    #expect(throws: SaveTeammateContactError.duplicateTeammate) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: true)
    }
    #expect(repository.notebook.contacts.count == 1)
  }

  @Test func sameNicknameOnAnotherServerIsADistinctLocalContact() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let saved = try SaveTeammateContactUseCase(repository: repository)
      .execute(SquadFixtures.draft(name: "Miko", server: .europeWest), permissionConfirmed: true)
    #expect(saved.profile.server == .europeWest)
    #expect(repository.notebook.contacts.count == 2)
  }

  @Test func editingTeammatePreservesTheirAvoidanceAndDoesNotAppendADuplicate() throws {
    var notebook = try SquadFixtures.notebook()
    let contact = try #require(notebook.contacts.first)
    notebook.avoidedPlayerIDs.insert(contact.id)
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let updated = try SaveTeammateContactUseCase(repository: repository).execute(
      SquadFixtures.draft(name: "MikoUpdated"), contactID: contact.id, permissionConfirmed: true)
    #expect(updated.id == contact.id)
    #expect(updated.profile.gamerTag == "MikoUpdated")
    #expect(repository.notebook.contacts == [updated])
    #expect(repository.notebook.avoidedPlayerIDs == [contact.id])
  }

  @Test func preventsRecordingTheOrganiserAsATeammate() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let draft = try SquadFixtures.draft(name: " ALEX ")
    #expect(throws: SaveTeammateContactError.cannotRecordYourself) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: true)
    }
  }

  @Test func editingAnUnknownContactDoesNotSilentlyCreateAnotherPlayer() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let draft = try SquadFixtures.draft(name: "Jade")
    #expect(throws: SaveTeammateContactError.contactNoLongerExists) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, contactID: PlayerIdentifier(), permissionConfirmed: true)
    }
    #expect(repository.notebook.contacts.count == 1)
  }

  @Test func failedContactSaveLeavesTheDirectoryUnchanged() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    repository.failsToSave = true
    let draft = try SquadFixtures.draft(name: "Jade")
    #expect(throws: SaveTeammateContactError.contactNotSaved) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: true)
    }
    #expect(repository.notebook == original)
  }

  @Test func unreadableDirectoryPreventsContactChanges() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    repository.failsToLoad = true
    let draft = try SquadFixtures.draft(name: "Jade")
    #expect(throws: SaveTeammateContactError.notebookUnavailable) {
      try SaveTeammateContactUseCase(repository: repository).execute(
        draft, permissionConfirmed: true)
    }
    #expect(repository.successfulSaveCount == 0)
  }
}
