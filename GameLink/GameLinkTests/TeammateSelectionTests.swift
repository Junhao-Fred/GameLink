import Testing

@testable import GameLink

@Suite("Moving from teammate results to proposal review")
@MainActor
struct TeammateSelectionTests {
  @Test func selectingAMatchOpensDetailsAndReturningToMatchesKeepsThePlan() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    let draft = planner.form
    let contact = try #require(repository.notebook.contacts.first)
    planner.openTeammate(contact.id)
    #expect(planner.selectedTab == .details)
    let details = try #require(planner.selectedTeammate)
    details.reviewProposal()
    #expect(details.proposalPreview?.teammate.id == contact.id)
    planner.returnToResults()
    #expect(planner.selectedTeammate == nil)
    #expect(planner.form == draft)
    #expect(planner.results != nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func invalidSelectionOrUnavailableResultsCannotOpenDetails() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    planner.openTeammate(PlayerIdentifier())
    #expect(planner.selectedTeammate == nil)
    let contact = try #require(repository.notebook.contacts.first)
    planner.refreshProfile(hasUnsavedProfileChanges: true)
    planner.openTeammate(contact.id)
    #expect(planner.selectedTeammate == nil)
    #expect(planner.selectedTab == .matches)
  }

  @Test func returningFromProfileRechecksOpenDetailsAndRecoveryRefreshesResults() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let planner = makePlanner(repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    planner.form.neededRole = .support
    planner.search()
    let contact = try #require(repository.notebook.contacts.first)
    planner.openTeammate(contact.id)
    let details = try #require(planner.selectedTeammate)
    details.reviewProposal()
    planner.refreshProfile(hasUnsavedProfileChanges: true)
    #expect(details.state == .unavailable(.unsavedProfileChanges))
    #expect(details.proposalPreview == nil)
    try SquadFixtures.saveLegacyExclusions([contact.id], in: repository)
    planner.refreshProfile(hasUnsavedProfileChanges: false)
    #expect(details.state == .unavailable(.preparation(.teammateAvoided)))
    planner.returnToResults()
    #expect(planner.selectedTeammate == nil)
    #expect(planner.selectedTab == .matches)
    guard case .available(let search) = planner.results?.state else {
      Issue.record("Returning to results should check the same plan again.")
      return
    }
    #expect(search.matches.isEmpty)
  }

  private func makePlanner(_ repository: TestSquadNotebookRepository) -> SessionPlanViewModel {
    SessionPlanViewModel(
      findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
  }
}
