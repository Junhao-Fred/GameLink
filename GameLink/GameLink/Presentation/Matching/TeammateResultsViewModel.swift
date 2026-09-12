import Observation

/// Presents current matches for one plan, keeping empty results distinct from read failures.
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

  /// Reruns matching against saved details, or hides results while profile edits are unsaved.
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
