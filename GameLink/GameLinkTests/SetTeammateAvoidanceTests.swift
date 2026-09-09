import Testing

@testable import GameLink

@Suite("Private teammate avoidance")
@MainActor
struct SetTeammateAvoidanceTests {
  @Test func avoidingATeammateRemovesThemFromFutureSearches() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let contact = try #require(repository.notebook.contacts.first)
    try SetTeammateAvoidanceUseCase(repository: repository).execute(
      teammateID: contact.id, isAvoided: true)
    #expect(repository.notebook.avoidedPlayerIDs == [contact.id])
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(search.matches.isEmpty)
    #expect(repository.notebook.contacts == [contact])
  }

  @Test func restoringATeammateMakesThemEligibleForANewSearch() throws {
    var notebook = try SquadFixtures.notebook()
    let contact = try #require(notebook.contacts.first)
    notebook.avoidedPlayerIDs.insert(contact.id)
    let repository = TestSquadNotebookRepository(notebook: notebook)
    try SetTeammateAvoidanceUseCase(repository: repository).execute(
      teammateID: contact.id, isAvoided: false)
    #expect(repository.notebook.avoidedPlayerIDs.isEmpty)
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(search.matches.map(\.id) == [contact.id])
  }

  @Test func repeatingAnAvoidancePreferenceDoesNotWriteAgain() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let contact = try #require(repository.notebook.contacts.first)
    let useCase = SetTeammateAvoidanceUseCase(repository: repository)
    try useCase.execute(teammateID: contact.id, isAvoided: true)
    try useCase.execute(teammateID: contact.id, isAvoided: true)
    #expect(repository.successfulSaveCount == 1)
  }

  @Test func organiserCannotAvoidTheirOwnProfile() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let organiser = try #require(repository.notebook.ownProfile)
    #expect(throws: SetTeammateAvoidanceError.cannotAvoidYourself) {
      try SetTeammateAvoidanceUseCase(repository: repository).execute(
        teammateID: organiser.id, isAvoided: true)
    }
    #expect(repository.notebook.avoidedPlayerIDs.isEmpty)
  }

  @Test func anUnknownPlayerCannotBeAddedToTheAvoidList() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    #expect(throws: SetTeammateAvoidanceError.teammateNoLongerExists) {
      try SetTeammateAvoidanceUseCase(repository: repository)
        .execute(teammateID: PlayerIdentifier(), isAvoided: true)
    }
  }

  @Test func aSavedOwnProfileIsRequiredToChangeAvoidance() {
    let repository = TestSquadNotebookRepository()
    #expect(throws: SetTeammateAvoidanceError.ownProfileRequired) {
      try SetTeammateAvoidanceUseCase(repository: repository)
        .execute(teammateID: PlayerIdentifier(), isAvoided: true)
    }
  }

  @Test(arguments: [true, false])
  func failedPreferenceSavePreservesThePreviousAvoidList(isAvoided: Bool) throws {
    var original = try SquadFixtures.notebook()
    let contact = try #require(original.contacts.first)
    original.avoidedPlayerIDs = isAvoided ? [] : [contact.id]
    let repository = TestSquadNotebookRepository(notebook: original)
    repository.failsToSave = true
    #expect(throws: SetTeammateAvoidanceError.preferenceNotSaved) {
      try SetTeammateAvoidanceUseCase(repository: repository)
        .execute(teammateID: contact.id, isAvoided: isAvoided)
    }
    #expect(repository.notebook == original)
  }

  @Test func unreadableAvoidanceIsNotSilentlyTreatedAsAnEmptyList() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let contact = try #require(repository.notebook.contacts.first)
    repository.failsToLoad = true
    #expect(throws: SetTeammateAvoidanceError.notebookUnavailable) {
      try SetTeammateAvoidanceUseCase(repository: repository)
        .execute(teammateID: contact.id, isAvoided: true)
    }
    #expect(repository.successfulSaveCount == 0)
  }
}
