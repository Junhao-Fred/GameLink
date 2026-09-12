import Foundation
import Observation

/// Coordinates teammate validation, proposal preview and user-initiated system sharing.
@MainActor
@Observable
final class TeammateDetailsViewModel {
  var plan: SquadPlan { search.plan }
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
  }

  func refresh(hasUnsavedProfileChanges: Bool) {
    self.hasUnsavedProfileChanges = hasUnsavedProfileChanges
    refresh()
  }

  func refresh() { _ = checkedProposal() }

  /// Reveals the inline preview only after rechecking the teammate and shared time.
  func reviewProposal() {
    guard let proposal = checkedProposal() else { return }
    shareOutcome = nil
    proposalPreview = proposal
  }

  /// Rechecks the notebook immediately before handing proposal text to system sharing.
  func requestSharing() {
    guard proposalPreview != nil, shareRequest == nil else { return }
    guard let proposal = checkedProposal() else { return }
    let request = SquadProposalShareRequest(id: UUID(), text: proposal.shareText)
    activeShareID = request.id
    shareOutcome = nil
    shareRequest = request
  }

  /// Records only the active request's outcome, ignoring callbacks from older share attempts.
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
      "Save your edits in Profile, then find teammates again in Plan before reviewing a proposal."
    case .preparation(let failure): failure.errorDescription
    }
  }
}
