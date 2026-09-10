import Foundation
import Testing

@testable import GameLink

@Suite("Handing a reviewed proposal to the system share interface")
@MainActor
struct SquadProposalSharingTests {
  @Test func sharingRequiresAnExplicitPreviewAndUsesExactlyItsMessage() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let details = try makeDetails(repository)
    details.refresh()
    details.requestSharing()
    #expect(details.shareRequest == nil)
    details.reviewProposal()
    let proposal = try #require(details.proposalPreview)
    details.requestSharing()
    let request = try #require(details.shareRequest)
    #expect(request.text == proposal.shareText)
    #expect(!request.text.contains(proposal.id.uuidString))
    #expect(!request.text.contains(proposal.teammate.id.rawValue.uuidString))
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test(arguments: ProposalStaleness.allCases)
  func changesAfterPreviewBlockTheShareRequest(_ change: ProposalStaleness) throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    let contact = try #require(repository.notebook.contacts.first)
    let expectedFailure: PrepareSquadProposalError
    switch change {
    case .missingOrganiser:
      repository.notebook.ownProfile = nil
      expectedFailure = .ownProfileRequired
    case .changedOrganiser:
      let organiser = try #require(repository.notebook.ownProfile)
      repository.notebook.ownProfile = try SquadFixtures.profile(
        id: organiser.id, name: "AlexUpdated")
      expectedFailure = .organiserDetailsChanged
    case .changedTeammate:
      repository.notebook.contacts = [
        try SquadFixtures.contact(id: contact.id, name: "MikoUpdated")
      ]
      expectedFailure = .teammateDetailsChanged
    case .avoidedTeammate:
      repository.notebook.avoidedPlayerIDs.insert(contact.id)
      expectedFailure = .teammateAvoided
    case .removedTeammate:
      repository.notebook.contacts = []
      expectedFailure = .teammateNoLongerExists
    case .unreadableNotebook:
      repository.failsToLoad = true
      expectedFailure = .notebookUnavailable
    }
    details.requestSharing()
    #expect(details.state == .unavailable(.preparation(expectedFailure)))
    #expect(details.proposalPreview == nil)
    #expect(details.shareRequest == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test(arguments: [SquadProposalShareOutcome.activityCompleted, .cancelled, .failed])
  func shareCallbacksNeverCreateABookingOrChangeSavedDetails(_ outcome: SquadProposalShareOutcome)
    throws
  {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let details = try makeDetails(repository)
    details.reviewProposal()
    let preview = try #require(details.proposalPreview)
    details.requestSharing()
    let request = try #require(details.shareRequest)
    details.completeSharing(requestID: request.id, outcome: outcome)
    #expect(details.shareRequest == nil)
    #expect(details.shareOutcome == outcome)
    #expect(details.proposalPreview == preview)
    #expect(preview.shareText.contains("not confirmed"))
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func completedActivityFeedbackDoesNotClaimDeliveryOrAgreement() {
    let message = SquadProposalShareOutcome.activityCompleted.message
    #expect(message.contains("cannot verify delivery or acceptance"))
    #expect(message.contains("Confirm the date"))
  }

  @Test func repeatedShareTapsKeepOneRequestAndRetryGetsANewIdentity() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    details.requestSharing()
    let first = try #require(details.shareRequest)
    details.requestSharing()
    #expect(details.shareRequest == first)
    details.completeSharing(requestID: first.id, outcome: .failed)
    details.requestSharing()
    let second = try #require(details.shareRequest)
    #expect(second.id != first.id)
    #expect(second.text == first.text)
    #expect(details.shareOutcome == nil)
    details.completeSharing(requestID: first.id, outcome: .activityCompleted)
    #expect(details.shareRequest == second)
    #expect(details.shareOutcome == nil)
  }

  @Test func closingThePreviewIgnoresLateCallbacksFromItsShareAction() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    details.requestSharing()
    let request = try #require(details.shareRequest)
    details.proposalPreview = nil
    details.completeSharing(requestID: request.id, outcome: .activityCompleted)
    #expect(details.shareRequest == nil)
    #expect(details.shareOutcome == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func dismissingTheShareSheetWithoutACallbackAllowsAnotherReviewedAttempt() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    let preview = try #require(details.proposalPreview)
    details.requestSharing()
    let dismissed = try #require(details.shareRequest)
    details.shareRequest = nil
    #expect(details.proposalPreview == preview)
    #expect(details.shareOutcome == nil)
    details.requestSharing()
    let retry = try #require(details.shareRequest)
    #expect(retry.id != dismissed.id)
    details.completeSharing(requestID: dismissed.id, outcome: .activityCompleted)
    #expect(details.shareRequest == retry)
    #expect(details.shareOutcome == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unresolvedProfileChangesInvalidateAPendingShareAndItsCallback() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let details = try makeDetails(repository)
    details.reviewProposal()
    details.requestSharing()
    let request = try #require(details.shareRequest)
    details.refresh(hasUnsavedProfileChanges: true)
    details.completeSharing(requestID: request.id, outcome: .activityCompleted)
    #expect(details.state == .unavailable(.unsavedProfileChanges))
    #expect(details.proposalPreview == nil)
    #expect(details.shareRequest == nil)
    #expect(details.shareOutcome == nil)
  }

  @Test func anotherRepositoryChangingAvoidanceBlocksAPreviouslyReviewedProposal() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let writer = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try writer.saveNotebook(SquadFixtures.notebook())
    let reader = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let search = try FindCompatibleTeammatesUseCase(repository: reader).execute(
      SquadFixtures.plan())
    let match = try #require(search.matches.first)
    let details = TeammateDetailsViewModel(
      teammateID: match.id, search: search,
      prepareProposal: PrepareSquadProposalUseCase(repository: reader))
    let originalBytes = try Data(contentsOf: sandbox.fileURL)
    details.reviewProposal()
    #expect(try Data(contentsOf: sandbox.fileURL) == originalBytes)
    try SetTeammateAvoidanceUseCase(repository: writer).execute(
      teammateID: match.id, isAvoided: true)
    let avoidedBytes = try Data(contentsOf: sandbox.fileURL)
    details.requestSharing()
    #expect(details.state == .unavailable(.preparation(.teammateAvoided)))
    #expect(details.shareRequest == nil)
    #expect(try Data(contentsOf: sandbox.fileURL) == avoidedBytes)
  }

  private func makeDetails(_ repository: TestSquadNotebookRepository) throws
    -> TeammateDetailsViewModel
  {
    let search = try FindCompatibleTeammatesUseCase(repository: repository).execute(
      SquadFixtures.plan())
    let match = try #require(search.matches.first)
    return TeammateDetailsViewModel(
      teammateID: match.id, search: search,
      prepareProposal: PrepareSquadProposalUseCase(repository: repository))
  }
}

nonisolated enum ProposalStaleness: CaseIterable, Sendable {
  case missingOrganiser, changedOrganiser, changedTeammate, avoidedTeammate, removedTeammate,
    unreadableNotebook
}
