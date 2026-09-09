import Foundation

@MainActor
struct FindCompatibleTeammatesUseCase {
  let repository: any SquadNotebookRepository

  func execute(_ plan: SquadPlan) throws(FindCompatibleTeammatesError) -> SquadSearch {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch { throw .notebookUnavailable }
    guard let organiser = notebook.ownProfile else { throw .ownProfileRequired }
    guard organiser.availability.contains(plan.playWindow) else { throw .outsideOwnAvailability }
    guard !plan.requiresVoiceChat || organiser.usesVoiceChat else { throw .ownVoiceChatUnavailable }

    let matches = notebook.contacts
      .filter { !notebook.avoidedPlayerIDs.contains($0.id) }
      .compactMap { plan.match(for: $0, organiser: organiser) }
      .sorted { first, second in
        if first.sharedWindow.durationMinutes != second.sharedWindow.durationMinutes {
          return first.sharedWindow.durationMinutes > second.sharedWindow.durationMinutes
        }
        if first.teammate.gamerTag != second.teammate.gamerTag {
          return first.teammate.gamerTag < second.teammate.gamerTag
        }
        return first.id.rawValue.uuidString < second.id.rawValue.uuidString
      }
    return SquadSearch(organiser: organiser, plan: plan, matches: matches)
  }
}

nonisolated enum FindCompatibleTeammatesError: LocalizedError, Equatable, Sendable {
  case ownProfileRequired
  case outsideOwnAvailability
  case ownVoiceChatUnavailable
  case notebookUnavailable

  var errorDescription: String? {
    switch self {
    case .ownProfileRequired:
      "Save your own profile before finding teammates."
    case .outsideOwnAvailability:
      "This session is outside your availability. Update your profile or choose another time."
    case .ownVoiceChatUnavailable:
      "Your profile says you do not use voice chat. Update your profile or make voice chat optional."
    case .notebookUnavailable:
      "Your saved squad details could not be read, so no search was run. Reopen GameLink and try again."
    }
  }
}
