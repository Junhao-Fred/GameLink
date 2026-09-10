import Foundation
import Observation

@MainActor
@Observable
final class TeammateDetailsViewModel {
  let plan: SquadPlan
  private(set) var state = TeammateDetailsState.checking
  var proposalPreview: SquadProposal? {
    didSet {
      if proposalPreview == nil {
        shareRequest = nil
        activeShareID = nil
        shareOutcome = nil
      }
    }
  }
  var shareRequest: SquadProposalShareRequest?
  private(set) var shareOutcome: SquadProposalShareOutcome?

  private let teammateID: PlayerIdentifier
  private let search: SquadSearch
  private let prepareProposal: PrepareSquadProposalUseCase
  private var hasUnsavedProfileChanges = false
  private var activeShareID: UUID?

  init(
    teammateID: PlayerIdentifier, search: SquadSearch,
    prepareProposal: PrepareSquadProposalUseCase
  ) {
    self.teammateID = teammateID
    self.search = search
    self.prepareProposal = prepareProposal
    plan = search.plan
  }

  func refresh(hasUnsavedProfileChanges: Bool) {
    self.hasUnsavedProfileChanges = hasUnsavedProfileChanges
    refresh()
  }

  func refresh() { _ = checkedProposal() }

  func reviewProposal() {
    guard let proposal = checkedProposal() else { return }
    shareOutcome = nil
    proposalPreview = proposal
  }

  func requestSharing() {
    guard proposalPreview != nil, shareRequest == nil else { return }
    guard let proposal = checkedProposal() else { return }
    let request = SquadProposalShareRequest(id: UUID(), text: proposal.shareText)
    activeShareID = request.id
    shareOutcome = nil
    shareRequest = request
  }

  func completeSharing(requestID: UUID, outcome: SquadProposalShareOutcome) {
    guard activeShareID == requestID else { return }
    shareOutcome = outcome
    shareRequest = nil
    activeShareID = nil
  }

  private func checkedProposal() -> SquadProposal? {
    guard !hasUnsavedProfileChanges else {
      invalidate(.unsavedProfileChanges)
      return nil
    }
    do {
      let proposal = try prepareProposal.execute(teammateID: teammateID, from: search)
      state = .available(proposal)
      return proposal
    } catch {
      invalidate(.preparation(error))
      return nil
    }
  }

  private func invalidate(_ failure: TeammateProposalFailure) {
    state = .unavailable(failure)
    proposalPreview = nil
  }
}

nonisolated enum TeammateDetailsState: Equatable {
  case checking
  case available(SquadProposal)
  case unavailable(TeammateProposalFailure)
}

nonisolated enum TeammateProposalFailure: LocalizedError, Equatable {
  case unsavedProfileChanges
  case preparation(PrepareSquadProposalError)

  var errorDescription: String? {
    switch self {
    case .unsavedProfileChanges:
      "Save or discard your edits in Profile, then return to Find before reviewing a proposal."
    case .preparation(let failure): failure.errorDescription
    }
  }
}
