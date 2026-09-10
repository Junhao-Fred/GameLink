import Testing

@testable import GameLink

@Suite("Planning a session from the organiser's saved details")
@MainActor
struct SessionPlanPresentationTests {
  @Test func aFirstLaunchRequestsAProfileAndDoesNotInventPlayers() {
    let repository = TestSquadNotebookRepository()
    let planner = makePlanner(repository)
    #expect(!planner.canSearch)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.search()
    #expect(planner.loadState == .ownProfileRequired)
    #expect(planner.results == nil)
    #expect(planner.path.isEmpty)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unreadableAvailabilityIsNotFirstLaunchAndCanBeRetried() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    repository.failsToLoad = true
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(planner.loadState == .unavailable(.profileUnavailable))
    #expect(!planner.canSearch)
    repository.failsToLoad = false
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(planner.loadState == .ready)
    #expect(planner.canSearch)
  }

  @Test func revisitingFindKeepsThePlayersChosenConditions() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .jungle
    planner.form.startMinute = 1170
    planner.form.durationMinutes = 60
    planner.form.requiresVoiceChat = true
    let chosenPlan = planner.form
    repository.notebook.ownProfile = try SquadFixtures.profile(day: .saturday)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(planner.form == chosenPlan)
    #expect(planner.savedProfile == repository.notebook.ownProfile)
  }

  @Test func unsavedProfileEditsBlockSearchWithoutDiscardingTheSessionDraft() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    let draft = planner.form
    planner.refreshProfile(hasUnsavedProfileChanges: true)
    planner.search()
    #expect(planner.loadState == .unsavedProfileChanges)
    #expect(!planner.canSearch)
    #expect(planner.results == nil)
    #expect(planner.form == draft)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(planner.canSearch)
  }

  @Test func aValidPlanOpensActualMatchesWithoutWritingTheNotebook() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    let results = try #require(planner.results)
    let expected = try FindCompatibleTeammatesUseCase(repository: repository).execute(
      planner.form.makePlan())
    #expect(results.state == .available(expected))
    #expect(planner.path == [.results])
    #expect(planner.searchFailure == nil)
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aMissingPositionStaysHighlightedUntilThatPositionIsChosen() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.search()
    #expect(planner.searchFailure == .form(.chooseNeededRole))
    #expect(planner.showsSearchFailure)
    planner.showsSearchFailure = false
    planner.form.durationMinutes = 60
    #expect(planner.searchFailure == .form(.chooseNeededRole))
    planner.form.neededRole = .support
    #expect(planner.searchFailure == nil)
  }

  @Test func aPlanOutsideAvailabilityReportsTheTimeFieldAndPreservesItsDraft() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.form.playDay = .saturday
    let draft = planner.form
    planner.search()
    #expect(planner.searchFailure == .search(.outsideOwnAvailability))
    #expect(planner.searchFailure?.field == .playWindow)
    #expect(planner.form == draft)
    #expect(planner.path.isEmpty)
    planner.form.playDay = .friday
    #expect(planner.searchFailure == nil)
  }

  @Test func requiringUnsupportedVoiceChatHasAnActionableFieldError() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile(voice: false)))
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.form.requiresVoiceChat = true
    planner.search()
    #expect(planner.searchFailure == .search(.ownVoiceChatUnavailable))
    #expect(planner.searchFailure?.field == .voiceChat)
    planner.form.requiresVoiceChat = false
    #expect(planner.searchFailure == nil)
    planner.search()
    #expect(planner.results != nil)
  }

  @Test func searchRechecksSavedAvailabilityEvenWithoutAScreenRefresh() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    repository.notebook.ownProfile = try SquadFixtures.profile(day: .saturday)
    planner.search()
    #expect(planner.searchFailure == .search(.outsideOwnAvailability))
    #expect(planner.results == nil)
  }

  @Test func aFailedSearchDoesNotReuseThePreviousMatchingPlayers() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    #expect(planner.results != nil)
    repository.failsToLoad = true
    planner.search()
    #expect(planner.results == nil)
    #expect(planner.path.isEmpty)
    #expect(planner.searchFailure == .search(.notebookUnavailable))
    repository.failsToLoad = false
    planner.search()
    #expect(planner.results != nil)
  }

  @Test func editingSessionConditionsInvalidatesResultsButBackNavigationKeepsTheDraft() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    let draft = planner.form
    planner.search()
    planner.path = []
    #expect(planner.form == draft)
    planner.form.neededRole = .jungle
    #expect(planner.results == nil)
    #expect(planner.path.isEmpty)
  }

  private func makePlanner(_ repository: TestSquadNotebookRepository) -> SessionPlanViewModel {
    SessionPlanViewModel(
      loadProfile: LoadGamingProfileUseCase(repository: repository),
      findTeammates: FindCompatibleTeammatesUseCase(repository: repository))
  }
}
