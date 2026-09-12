import Testing

@testable import GameLink

@Suite("Four destinations for planning with saved teammates")
@MainActor
struct WorkspaceNavigationTests {
  @Test func searchingSwitchesFromPlanToMatches() throws {
    let planner = try makePlanner()
    planner.search()
    #expect(planner.selectedTab == .matches)
    #expect(planner.results != nil)
  }

  @Test func choosingAMatchSwitchesToDetails() throws {
    let planner = try makePlanner()
    planner.search()
    let teammateID = try firstMatch(in: planner)
    planner.openTeammate(teammateID)
    #expect(planner.selectedTab == .details)
    let details = try #require(planner.selectedTeammate)
    details.refresh()
    guard case .available(let proposal) = details.state else {
      Issue.record("Selecting a compatible teammate should make their details available.")
      return
    }
    #expect(proposal.teammate.id == teammateID)
  }

  @Test func switchingTabsKeepsTheSelectedTeammateAndSessionDraft() throws {
    let planner = try makePlanner()
    planner.search()
    planner.openTeammate(try firstMatch(in: planner))
    let details = try #require(planner.selectedTeammate)
    let draft = planner.form
    for tab in [GameLinkTab.profile, .plan, .matches, .details] {
      planner.selectedTab = tab
      #expect(planner.selectedTeammate === details)
      #expect(planner.form == draft)
      #expect(planner.results != nil)
    }
  }

  @Test func changingSessionConditionsClearsBothMatchesAndDetails() throws {
    let planner = try makePlanner()
    planner.search()
    planner.openTeammate(try firstMatch(in: planner))
    planner.selectedTab = .plan
    planner.form.neededRole = .jungle
    #expect(planner.results == nil)
    #expect(planner.selectedTeammate == nil)
    #expect(planner.selectedTab == .plan)
  }

  @Test func returningToMatchesClearsTheRejectedProposalSelection() throws {
    let planner = try makePlanner()
    planner.search()
    planner.openTeammate(try firstMatch(in: planner))
    planner.selectedTab = .details
    planner.returnToResults()
    #expect(planner.selectedTab == .matches)
    #expect(planner.selectedTeammate == nil)
    #expect(planner.results != nil)
  }

  @Test func openingEmptyDestinationsDoesNotInventSearchResultsOrWritePlayers() {
    let repository = TestSquadNotebookRepository()
    let planner = SessionPlanViewModel(
      findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    for tab in [GameLinkTab.matches, .details] {
      planner.selectedTab = tab
      #expect(planner.results == nil)
      #expect(planner.selectedTeammate == nil)
      #expect(planner.loadState == .ownProfileRequired)
    }
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func returningToRecoveredMatchesAllowsOpeningDetails() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = SessionPlanViewModel(
      findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    let teammateID = try firstMatch(in: planner)
    let draft = planner.form

    repository.failsToLoad = true
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(!planner.canSearch)
    repository.failsToLoad = false
    planner.returnToResults()

    #expect(try firstMatch(in: planner) == teammateID)
    planner.openTeammate(teammateID)
    #expect(planner.selectedTab == .details)
    #expect(planner.selectedTeammate != nil)
    #expect(planner.form == draft)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func refreshingMatchesCannotBypassUnfinishedProfileEdits() throws {
    let planner = try makePlanner()
    planner.search()
    let teammateID = try firstMatch(in: planner)
    planner.refreshProfile(hasUnsavedProfileChanges: true)
    planner.returnToResults()
    planner.openTeammate(teammateID)
    #expect(planner.results?.state == .unsavedProfileChanges)
    #expect(planner.selectedTab == .matches)
    #expect(planner.selectedTeammate == nil)
    #expect(!planner.canSearch)
  }

  private func makePlanner() throws -> SessionPlanViewModel {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = SessionPlanViewModel(
      findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    return planner
  }

  private func firstMatch(in planner: SessionPlanViewModel) throws -> PlayerIdentifier {
    let results = try #require(planner.results)
    guard case .available(let search) = results.state else {
      throw FindCompatibleTeammatesError.notebookUnavailable
    }
    return try #require(search.matches.first?.id)
  }
}
