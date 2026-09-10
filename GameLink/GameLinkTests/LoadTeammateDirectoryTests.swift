import Testing

@testable import GameLink

@MainActor
struct LoadTeammateDirectoryTests {
  @Test func savedTeammatesRetainTheirOrderAndPrivateAvoidanceStatus() throws {
    var notebook = try SquadFixtures.notebook()
    notebook.contacts.append(try SquadFixtures.contact(name: "Jordan"))
    notebook.avoidedPlayerIDs = [try #require(notebook.contacts.first).id]
    let repository = TestSquadNotebookRepository(notebook: notebook)

    let entries = try LoadTeammateDirectoryUseCase(repository: repository).execute()

    #expect(entries.map(\.contact) == notebook.contacts)
    #expect(entries.map(\.isAvoided) == [true, false])
    #expect(repository.notebook == notebook)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aSavedOrganiserWithNoContactsHasAnEmptyDirectory() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile()))
    #expect(try LoadTeammateDirectoryUseCase(repository: repository).execute().isEmpty)
  }

  @Test func aFirstLaunchRequiresThePlayersOwnProfileBeforeManagingTeammates() {
    let repository = TestSquadNotebookRepository()
    #expect(throws: LoadTeammateDirectoryError.ownProfileRequired) {
      try LoadTeammateDirectoryUseCase(repository: repository).execute()
    }
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unreadableSavedTeammatesAreNotReportedAsAnEmptyDirectory() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    repository.failsToLoad = true
    #expect(throws: LoadTeammateDirectoryError.directoryUnavailable) {
      try LoadTeammateDirectoryUseCase(repository: repository).execute()
    }
  }

  @Test func reloadingSeesContactsAddedSinceThePreviousRead() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile()))
    let loadDirectory = LoadTeammateDirectoryUseCase(repository: repository)
    #expect(try loadDirectory.execute().isEmpty)
    let teammate = try SaveTeammateContactUseCase(repository: repository).execute(
      SquadFixtures.draft(name: "Miko"), permissionConfirmed: true)
    #expect(try loadDirectory.execute().map(\.id) == [teammate.id])
  }
}
