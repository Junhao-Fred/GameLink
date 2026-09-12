import Foundation

/// Rechecks a match before creating an unconfirmed proposal.
@MainActor
struct PrepareSquadProposalUseCase {
  let repository: any SquadNotebookRepository
  let matchingRule: any TeammateMatchingRule

  init(
    repository: any SquadNotebookRepository,
    matchingRule: any TeammateMatchingRule = SavedTeammateMatchingRule()
  ) {
    self.repository = repository
    self.matchingRule = matchingRule
  }

  /// Reloads profiles and exclusions, rejects stale matches and recalculates shared time.
  func execute(
    teammateID: PlayerIdentifier, from search: SquadSearch
  ) throws(PrepareSquadProposalError) -> SquadProposal {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }
    guard let organiser = notebook.ownProfile else { throw .ownProfileRequired }
    guard organiser == search.organiser else { throw .organiserDetailsChanged }
    guard let selected = search.matches.first(where: { $0.id == teammateID }) else {
      throw .teammateNotInSearch
    }
    guard !notebook.avoidedPlayerIDs.contains(teammateID) else { throw .teammateAvoided }
    guard let contact = notebook.contacts.first(where: { $0.id == teammateID }) else {
      throw .teammateNoLongerExists
    }
    guard contact.profile == selected.teammate else { throw .teammateDetailsChanged }
    guard organiser.availability.contains(search.plan.playWindow),
      !search.plan.requiresVoiceChat || organiser.usesVoiceChat,
      let currentMatch = matchingRule.match(for: contact, organiser: organiser, plan: search.plan)
    else { throw .noLongerCompatible }

    return SquadProposal(
      organiser: organiser, teammate: contact.profile,
      sharedWindow: currentMatch.sharedWindow, requiresVoiceChat: search.plan.requiresVoiceChat)
  }
}

nonisolated enum PrepareSquadProposalError: LocalizedError, Equatable, Sendable {
  case ownProfileRequired
  case organiserDetailsChanged
  case teammateNotInSearch
  case teammateAvoided
  case teammateNoLongerExists
  case teammateDetailsChanged
  case noLongerCompatible
  case notebookUnavailable
  case notebookAccess(SquadNotebookAccessError)

  var errorDescription: String? {
    switch self {
    case .ownProfileRequired:
      "Save your own profile and search again before preparing a proposal."
    case .organiserDetailsChanged:
      "Your profile has changed since this search. Find teammates again using your saved details."
    case .teammateNotInSearch:
      "This player is not in these search results. Search again and select an eligible teammate."
    case .teammateAvoided:
      "This teammate was excluded from matching in an earlier version. Choose another teammate from Matches."
    case .teammateNoLongerExists:
      "This teammate is no longer in your directory. Return to your teammate list and search again."
    case .teammateDetailsChanged:
      "These teammate details have changed. Search again before preparing a proposal."
    case .noLongerCompatible:
      "This teammate does not meet the session conditions. Review the time, role, and voice preference, then search again."
    case .notebookAccess(let reason): reason.errorDescription
    case .notebookUnavailable:
      "Your saved squad details could not be checked. No proposal was prepared. Reopen GameLink and try again."
    }
  }
}
