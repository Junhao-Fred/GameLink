import Testing

@testable import GameLink

@Suite("Preparing an unconfirmed squad proposal")
@MainActor
struct PrepareSquadProposalTests {
  @Test func proposalUsesActualSharedTimeNotTheEntireRequestedSession() throws {
    let contact = try SquadFixtures.contact(start: 1230, duration: 60)
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile(), contacts: [contact]))
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let proposal = try PrepareSquadProposalUseCase(repository: repository)
      .execute(teammateID: contact.id, from: search)
    #expect(proposal.sharedWindow.startMinute == 1230)
    #expect(proposal.sharedWindow.durationMinutes == 30)
    #expect(proposal.shareText.contains("Friday 20:30-21:00 (Australia/Sydney)"))
    #expect(proposal.shareText.contains("not confirmed"))
    #expect(proposal.shareText.contains("confirm the exact date"))
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func changedOrganiserProfileRequiresANewSearch() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    _ = try SaveGamingProfileUseCase(repository: repository)
      .execute(SquadFixtures.draft(name: "AlexUpdated"))
    #expect(throws: PrepareSquadProposalError.organiserDetailsChanged) {
      try PrepareSquadProposalUseCase(repository: repository).execute(
        teammateID: match.id, from: search)
    }
  }

  @Test func changedTeammateProfileRequiresANewSearch() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    _ = try SaveTeammateContactUseCase(repository: repository).execute(
      SquadFixtures.draft(name: "Miko", role: .support, start: 1170, duration: 90),
      contactID: match.id, permissionConfirmed: true)
    #expect(throws: PrepareSquadProposalError.teammateDetailsChanged) {
      try PrepareSquadProposalUseCase(repository: repository).execute(
        teammateID: match.id, from: search)
    }
  }

  @Test func avoidanceAddedAfterSearchingBlocksTheExistingResult() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    try SetTeammateAvoidanceUseCase(repository: repository).execute(
      teammateID: match.id, isAvoided: true)
    #expect(throws: PrepareSquadProposalError.teammateAvoided) {
      try PrepareSquadProposalUseCase(repository: repository).execute(
        teammateID: match.id, from: search)
    }
  }

  @Test func removedContactCannotReceiveAProposalFromOldResults() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    repository.notebook.contacts = []
    #expect(throws: PrepareSquadProposalError.teammateNoLongerExists) {
      try PrepareSquadProposalUseCase(repository: repository).execute(
        teammateID: match.id, from: search)
    }
  }

  @Test func aPlayerOutsideTheSearchResultsCannotBeSelected() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(throws: PrepareSquadProposalError.teammateNotInSearch) {
      try PrepareSquadProposalUseCase(repository: repository)
        .execute(teammateID: PlayerIdentifier(), from: search)
    }
  }

  @Test func missingOwnProfileBlocksProposalPreparation() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    repository.notebook.ownProfile = nil
    #expect(throws: PrepareSquadProposalError.ownProfileRequired) {
      try PrepareSquadProposalUseCase(repository: repository).execute(
        teammateID: match.id, from: search)
    }
  }

  @Test func proposalRevalidatesRoleEvenWhenGivenAnInconsistentSearchSnapshot() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let organiser = try #require(notebook.ownProfile)
    let contact = try #require(notebook.contacts.first)
    let invalidSearch = SquadSearch(
      organiser: organiser, plan: try SquadFixtures.plan(role: .jungle),
      matches: [TeammateMatch(teammate: contact.profile, sharedWindow: try SquadFixtures.window())])
    #expect(throws: PrepareSquadProposalError.noLongerCompatible) {
      try PrepareSquadProposalUseCase(repository: repository)
        .execute(teammateID: contact.id, from: invalidSearch)
    }
  }

  @Test func proposalRecalculatesSharedTimeInsteadOfTrustingCachedMatchDuration() throws {
    let contact = try SquadFixtures.contact(start: 1230, duration: 60)
    let organiser = try SquadFixtures.profile()
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: organiser, contacts: [contact]))
    let search = SquadSearch(
      organiser: organiser, plan: try SquadFixtures.plan(),
      matches: [TeammateMatch(teammate: contact.profile, sharedWindow: try SquadFixtures.window())])
    let proposal = try PrepareSquadProposalUseCase(repository: repository)
      .execute(teammateID: contact.id, from: search)
    #expect(proposal.sharedWindow.durationMinutes == 30)
    #expect(proposal.sharedWindow.startMinute == 1230)
  }

  @Test func unreadableNotebookPreventsUncheckedProposalPreparation() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    repository.failsToLoad = true
    #expect(throws: PrepareSquadProposalError.notebookUnavailable) {
      try PrepareSquadProposalUseCase(repository: repository).execute(
        teammateID: match.id, from: search)
    }
  }
}
