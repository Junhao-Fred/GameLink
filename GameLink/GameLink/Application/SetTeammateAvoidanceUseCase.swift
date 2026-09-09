import Foundation

@MainActor
struct SetTeammateAvoidanceUseCase {
  let repository: any SquadNotebookRepository

  func execute(
    teammateID: PlayerIdentifier, isAvoided: Bool
  ) throws(SetTeammateAvoidanceError) {
    var notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch { throw .notebookUnavailable }
    guard let organiser = notebook.ownProfile else { throw .ownProfileRequired }
    guard teammateID != organiser.id else { throw .cannotAvoidYourself }
    guard notebook.contacts.contains(where: { $0.id == teammateID }) else {
      throw .teammateNoLongerExists
    }
    guard notebook.avoidedPlayerIDs.contains(teammateID) != isAvoided else { return }
    if isAvoided {
      notebook.avoidedPlayerIDs.insert(teammateID)
    } else {
      notebook.avoidedPlayerIDs.remove(teammateID)
    }
    do { try repository.saveNotebook(notebook) } catch { throw .preferenceNotSaved }
  }
}

nonisolated enum SetTeammateAvoidanceError: LocalizedError, Equatable, Sendable {
  case ownProfileRequired
  case cannotAvoidYourself
  case teammateNoLongerExists
  case notebookUnavailable
  case preferenceNotSaved

  var errorDescription: String? {
    switch self {
    case .ownProfileRequired:
      "Save your profile before changing teammate preferences."
    case .cannotAvoidYourself:
      "You cannot add your own profile to the avoid list. Choose a teammate instead."
    case .teammateNoLongerExists:
      "This teammate is no longer in your directory. Return to your teammate list before changing preferences."
    case .notebookUnavailable:
      "Your private avoid list could not be read. Reopen GameLink and try again before changing preferences."
    case .preferenceNotSaved:
      "Your teammate preference was not saved. The previous avoid list is unchanged. Try again."
    }
  }
}
