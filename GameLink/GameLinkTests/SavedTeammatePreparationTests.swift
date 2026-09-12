import Testing

@testable import GameLink

@MainActor
struct SavedTeammatePreparationTests {
  @Test func savedTeammatesRetainTheirOrderAndPrivateAvoidanceStatus() throws {
    var notebook = try SquadFixtures.notebook()
    notebook.contacts.append(try SquadFixtures.contact(name: "Jordan"))
    notebook.avoidedPlayerIDs = [try #require(notebook.contacts.first).id]
    let repository = TestSquadNotebookRepository(notebook: notebook)

    let entries = try SaveTeammateContactUseCase(repository: repository).loadSavedTeammates()

    #expect(entries.map(\.contact) == notebook.contacts)
    #expect(entries.map(\.isAvoided) == [true, false])
    #expect(repository.notebook == notebook)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aSavedOrganiserWithNoContactsHasAnEmptyDirectory() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile()))
    #expect(try SaveTeammateContactUseCase(repository: repository).loadSavedTeammates().isEmpty)
  }

  @Test func aFirstLaunchRequiresThePlayersOwnProfileBeforeManagingTeammates() {
    let repository = TestSquadNotebookRepository()
    #expect(throws: SaveTeammateContactError.ownProfileRequired) {
      try SaveTeammateContactUseCase(repository: repository).loadSavedTeammates()
    }
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unreadableSavedTeammatesAreNotReportedAsAnEmptyDirectory() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    repository.failsToLoad = true
    #expect(throws: SaveTeammateContactError.notebookUnavailable) {
      try SaveTeammateContactUseCase(repository: repository).loadSavedTeammates()
    }
  }

  @Test func reloadingSeesContactsAddedSinceThePreviousRead() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile()))
    let saveContact = SaveTeammateContactUseCase(repository: repository)
    #expect(try saveContact.loadSavedTeammates().isEmpty)
    let teammate = try SaveTeammateContactUseCase(repository: repository).execute(
      SquadFixtures.draft(name: "Miko"), permissionConfirmed: true)
    #expect(try saveContact.loadSavedTeammates().map(\.id) == [teammate.id])
  }
}
