import Testing

@testable import GameLink

@MainActor
struct OrganiserSearchPreparationTests {
  @Test func preparingASearchUsesTheSavedOrganiserWithoutWriting() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let organiser = try FindCompatibleTeammatesUseCase(repository: repository).loadOrganiser()
    #expect(organiser == repository.notebook.ownProfile)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func planningWithoutASavedOrganiserRequiresProfileSetup() {
    let repository = TestSquadNotebookRepository()
    #expect(throws: FindCompatibleTeammatesError.ownProfileRequired) {
      try FindCompatibleTeammatesUseCase(repository: repository).loadOrganiser()
    }
  }

  @Test func unreadableSearchContextIsNotMistakenForAMissingProfile() {
    let repository = TestSquadNotebookRepository()
    repository.failsToLoad = true
    #expect(throws: FindCompatibleTeammatesError.notebookUnavailable) {
      try FindCompatibleTeammatesUseCase(repository: repository).loadOrganiser()
    }
    #expect(repository.successfulSaveCount == 0)
  }
}
