import Testing

@testable import GameLink

@Suite("Reviewing a saved teammate before proposing a session")
@MainActor
struct TeammateDetailsPresentationTests {
  @Test func openingDetailsShowsActualSharedTimeWithoutOpeningSharing() throws {
    let contact = try SquadFixtures.contact(start: 1230, duration: 60)
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile(), contacts: [contact]))
    let details = try makeDetails(repository)
    #expect(details.state == .checking)
    details.refresh()
    guard case .available(let proposal) = details.state else {
      Issue.record("The compatible teammate should be available for review.")
      return
    }
    #expect(proposal.teammate == contact.profile)
    #expect(proposal.sharedWindow.startMinute == 1230)
    #expect(proposal.sharedWindow.durationMinutes == 30)
    #expect(details.proposalPreview == nil)
    #expect(details.shareRequest == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func reviewingAProposalProducesAnUnconfirmedMessageWithoutSendingIt() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let details = try makeDetails(repository)
    details.reviewProposal()
    let proposal = try #require(details.proposalPreview)
    #expect(proposal.shareText.contains("From: Alex"))
    #expect(proposal.shareText.contains("To: Miko"))
    #expect(proposal.shareText.contains("not confirmed"))
    #expect(proposal.shareText.contains("confirm the exact date"))
    #expect(details.shareRequest == nil)
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unchangedForegroundRefreshKeepsTheReviewedPreviewIdentity() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    let preview = try #require(details.proposalPreview)
    details.refresh(hasUnsavedProfileChanges: false)
    #expect(details.proposalPreview == preview)
    #expect(details.shareRequest == nil)
  }

  @Test func unreadableDetailsHideTheOldPreviewAndCanBeCheckedAgain() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    repository.failsToLoad = true
    details.refresh()
    #expect(details.state == .unavailable(.preparation(.notebookUnavailable)))
    #expect(details.proposalPreview == nil)
    repository.failsToLoad = false
    details.refresh()
    guard case .available = details.state else {
      Issue.record("Retry should check the saved teammate again.")
      return
    }
    #expect(details.proposalPreview == nil)
    details.reviewProposal()
    #expect(details.proposalPreview != nil)
  }

  @Test func unsavedProfileEditsBlockReviewUntilTheyAreResolved() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    details.refresh(hasUnsavedProfileChanges: true)
    details.reviewProposal()
    details.requestSharing()
    #expect(details.state == .unavailable(.unsavedProfileChanges))
    #expect(details.proposalPreview == nil)
    #expect(details.shareRequest == nil)
    details.refresh(hasUnsavedProfileChanges: false)
    details.reviewProposal()
    #expect(details.proposalPreview != nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aPlayerOutsideTheSearchHasNoUncheckedDetailOrProposal() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let details = TeammateDetailsViewModel(
      teammateID: PlayerIdentifier(), search: search,
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
    details.reviewProposal()
    #expect(details.state == .unavailable(.preparation(.teammateNotInSearch)))
    #expect(details.proposalPreview == nil)
  }

  private func makeDetails(_ repository: TestSquadNotebookRepository) throws
    -> TeammateDetailsViewModel
  {
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    return TeammateDetailsViewModel(
      teammateID: match.id, search: search,
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
  }
}
