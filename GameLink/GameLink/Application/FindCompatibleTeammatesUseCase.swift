import Foundation

/// Finds saved teammates for a session within the organiser's availability.
@MainActor
struct FindCompatibleTeammatesUseCase {
  let repository: any SquadNotebookRepository
  let matchingRule: any TeammateMatchingRule

  init(
    repository: any SquadNotebookRepository,
    matchingRule: any TeammateMatchingRule = SavedTeammateMatchingRule()
  ) {
    self.repository = repository
    self.matchingRule = matchingRule
  }

  /// Loads the organiser to set the initial session time.
  func loadOrganiser() throws(FindCompatibleTeammatesError) -> GamingProfile {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }
    guard let organiser = notebook.ownProfile else { throw .ownProfileRequired }
    return organiser
  }

  /// Excludes avoided players and sorts matches by longest shared time.
  func execute(_ plan: SquadPlan) throws(FindCompatibleTeammatesError) -> SquadSearch {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }
    guard let organiser = notebook.ownProfile else { throw .ownProfileRequired }
    guard organiser.availability.contains(plan.playWindow) else { throw .outsideOwnAvailability }
    guard !plan.requiresVoiceChat || organiser.usesVoiceChat else { throw .ownVoiceChatUnavailable }

    let matches = notebook.contacts
      .filter { !notebook.avoidedPlayerIDs.contains($0.id) }
      .compactMap { matchingRule.match(for: $0, organiser: organiser, plan: plan) }
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
  case notebookAccess(SquadNotebookAccessError)

  var errorDescription: String? {
    switch self {
    case .ownProfileRequired:
      "Save your own profile before finding teammates."
    case .outsideOwnAvailability:
      "This session is outside your availability. Update your profile or choose another time."
    case .ownVoiceChatUnavailable:
      "Your profile says you do not use voice chat. Update your profile or make voice chat optional."
    case .notebookAccess(let reason): reason.errorDescription
    case .notebookUnavailable:
      "Your saved squad details could not be read. Unlock your device and try again before finding teammates. Keep your saved data."
    }
  }
}
