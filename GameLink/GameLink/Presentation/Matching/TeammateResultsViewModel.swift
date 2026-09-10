import Observation

@MainActor
@Observable
final class TeammateResultsViewModel {
  let plan: SquadPlan
  private(set) var state: TeammateResultsState
  private var hasUnsavedProfileChanges = false
  private let findTeammates: FindCompatibleTeammatesUseCase

  init(search: SquadSearch, findTeammates: FindCompatibleTeammatesUseCase) {
    plan = search.plan
    state = .available(search)
    self.findTeammates = findTeammates
  }

  func refresh(hasUnsavedProfileChanges: Bool) {
    self.hasUnsavedProfileChanges = hasUnsavedProfileChanges
    refresh()
  }

  func refresh() {
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
