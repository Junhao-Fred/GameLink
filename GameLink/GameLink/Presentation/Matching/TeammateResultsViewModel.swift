import Observation

/// Shows matches for one plan and distinguishes no matches from a read failure.
@MainActor
@Observable
final class TeammateResultsViewModel {
  let plan: SquadPlan
  private(set) var state: TeammateResultsState
  private let findTeammates: FindCompatibleTeammatesUseCase

  init(search: SquadSearch, findTeammates: FindCompatibleTeammatesUseCase) {
    plan = search.plan
    state = .available(search)
    self.findTeammates = findTeammates
  }

  /// Refreshes saved matches, or hides them while profile edits are unsaved.
  func refresh(hasUnsavedProfileChanges: Bool) {
    guard !hasUnsavedProfileChanges else {
      state = .unsavedProfileChanges
      return
    }
    do {
      state = .available(try findTeammates.execute(plan))
    } catch { state = .unavailable(error) }
  }
}

nonisolated enum TeammateResultsState: Equatable {
  case available(SquadSearch)
  case unavailable(FindCompatibleTeammatesError)
  case unsavedProfileChanges
}
