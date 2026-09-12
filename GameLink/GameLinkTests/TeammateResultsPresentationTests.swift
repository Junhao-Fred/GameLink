import Testing

@testable import GameLink

@Suite("Keeping teammate results aligned with saved session conditions")
@MainActor
struct TeammateResultsPresentationTests {
  @Test func restoredLegacyExclusionsUpdateOpenResults() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let finder = FindCompatibleTeammatesUseCase(repository: repository)
    let original = try finder.execute(SquadFixtures.plan())
    let results = TeammateResultsViewModel(search: original, findTeammates: finder)
    let teammate = try #require(original.matches.first)
    try SquadFixtures.saveLegacyExclusions([teammate.id], in: repository)
    results.refresh(hasUnsavedProfileChanges: false)
    #expect(
      results.state
        == .available(SquadSearch(organiser: original.organiser, plan: original.plan, matches: [])))
    try SquadFixtures.saveLegacyExclusions([], in: repository)
    results.refresh(hasUnsavedProfileChanges: false)
    #expect(results.state == .available(original))
  }

  @Test func unavailableStorageHidesOldResultsAndRetryRechecksTheNotebook() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let finder = FindCompatibleTeammatesUseCase(repository: repository)
    let original = try finder.execute(SquadFixtures.plan())
    let results = TeammateResultsViewModel(search: original, findTeammates: finder)
    repository.failsToLoad = true
    results.refresh(hasUnsavedProfileChanges: false)
    #expect(results.state == .unavailable(.notebookUnavailable))
    repository.failsToLoad = false
    repository.notebook.contacts = []
    results.refresh(hasUnsavedProfileChanges: false)
    #expect(
      results.state
        == .available(SquadSearch(organiser: original.organiser, plan: original.plan, matches: [])))
  }

  @Test func unsavedProfileEditsHideResultsUntilThePlanningContextIsReviewed() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = SessionPlanViewModel(
      findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    let results = try #require(planner.results)
    let original = results.state
    planner.refreshProfile(hasUnsavedProfileChanges: true)
    #expect(results.state == .unsavedProfileChanges)
    planner.returnToResults()
    #expect(results.state == .unsavedProfileChanges)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(results.state == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aChangedOrganiserWindowInvalidatesTheOldResults() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let finder = FindCompatibleTeammatesUseCase(repository: repository)
    let results = TeammateResultsViewModel(
      search: try finder.execute(SquadFixtures.plan()), findTeammates: finder)
    repository.notebook.ownProfile = try SquadFixtures.profile(duration: 60)
    results.refresh(hasUnsavedProfileChanges: false)
    #expect(results.state == .unavailable(.outsideOwnAvailability))
    repository.notebook.ownProfile = nil
    results.refresh(hasUnsavedProfileChanges: false)
    #expect(results.state == .unavailable(.ownProfileRequired))
  }

  @Test func resultsKeepRankedActualSharedWindowsRatherThanClaimingTheWholeSession() throws {
    let organiser = try SquadFixtures.profile()
    let shortContact = try SquadFixtures.contact(name: "Short overlap", start: 1230, duration: 60)
    let longContact = try SquadFixtures.contact(name: "Long overlap", start: 1170, duration: 90)
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: organiser, contacts: [shortContact, longContact]))
    let finder = FindCompatibleTeammatesUseCase(repository: repository)
    let plan = try SquadFixtures.plan()
    let results = TeammateResultsViewModel(search: try finder.execute(plan), findTeammates: finder)
    let expected = SquadSearch(
      organiser: organiser, plan: plan,
      matches: [
        TeammateMatch(
          teammate: longContact.profile,
          sharedWindow: try SquadFixtures.window(start: 1170, duration: 90)),
        TeammateMatch(
          teammate: shortContact.profile,
          sharedWindow: try SquadFixtures.window(start: 1230, duration: 30)),
      ])
    #expect(results.state == .available(expected))
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func reopenedStorageSuppliesSearchResultsAndLegacyExclusions() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let writer = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let original = try SquadFixtures.notebook()
    try writer.saveNotebook(original)
    let reader = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let planner = SessionPlanViewModel(
      findTeammates: FindCompatibleTeammatesUseCase(repository: reader),
      prepareProposal: PrepareSquadProposalUseCase(repository: reader))
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    let results = try #require(planner.results)
    let organiser = try #require(original.ownProfile)
    let teammate = try #require(original.contacts.first)
    try SquadFixtures.saveLegacyExclusions([teammate.id], in: writer)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(
      results.state
        == .available(
          SquadSearch(organiser: organiser, plan: try planner.form.makePlan(), matches: [])))
    #expect(try reader.loadNotebook().contacts == original.contacts)
  }
}
