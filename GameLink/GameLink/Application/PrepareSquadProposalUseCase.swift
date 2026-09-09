import Foundation

@MainActor
struct PrepareSquadProposalUseCase {
  let repository: any SquadNotebookRepository

  func execute(
    teammateID: PlayerIdentifier, from search: SquadSearch
  ) throws(PrepareSquadProposalError) -> SquadProposal {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch { throw .notebookUnavailable }
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
      let currentMatch = search.plan.match(for: contact, organiser: organiser)
    else { throw .noLongerCompatible }

    return SquadProposal(
      id: UUID(), organiser: organiser, teammate: contact.profile,
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

  var errorDescription: String? {
    switch self {
    case .ownProfileRequired:
      "Save your own profile and search again before preparing a proposal."
    case .organiserDetailsChanged:
      "Your profile has changed since this search. Find teammates again using your saved details."
    case .teammateNotInSearch:
      "This player is not in these search results. Search again and select an eligible teammate."
    case .teammateAvoided:
      "This player is on your private avoid list. Restore them in Profile and search again if you want to play together."
    case .teammateNoLongerExists:
      "This teammate is no longer in your directory. Return to your teammate list and search again."
    case .teammateDetailsChanged:
      "These teammate details have changed. Search again before preparing a proposal."
    case .noLongerCompatible:
      "This teammate does not meet the session conditions. Review the time, role, and voice preference, then search again."
    case .notebookUnavailable:
      "Your saved squad details could not be checked. No proposal was prepared. Reopen GameLink and try again."
    }
  }
}
