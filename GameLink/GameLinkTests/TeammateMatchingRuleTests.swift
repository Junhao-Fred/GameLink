import Testing

@testable import GameLink

@Suite("Business operations share the teammate eligibility contract")
@MainActor
struct TeammateMatchingRuleTests {
  @Test func aRejectedTeammateIsNeitherListedNorProposed() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let plan = try SquadFixtures.plan()
    let previousSearch = try FindCompatibleTeammatesUseCase(repository: repository).execute(plan)
    let teammateID = try #require(previousSearch.matches.first?.id)
    let rule: any TeammateMatchingRule = NoEligibleTeammates()

    let currentSearch = try FindCompatibleTeammatesUseCase(
      repository: repository, matchingRule: rule
    ).execute(plan)
    #expect(currentSearch.matches.isEmpty)
    #expect(throws: PrepareSquadProposalError.noLongerCompatible) {
      try PrepareSquadProposalUseCase(repository: repository, matchingRule: rule).execute(
        teammateID: teammateID, from: previousSearch)
    }
    #expect(repository.successfulSaveCount == 0)
  }
}

nonisolated private struct NoEligibleTeammates: TeammateMatchingRule {
  func match(
    for contact: TeammateContact, organiser: GamingProfile, plan: SquadPlan
  ) -> TeammateMatch? { nil }
}
