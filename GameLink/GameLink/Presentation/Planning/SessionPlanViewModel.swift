import Foundation
import Observation

@MainActor
@Observable
final class SessionPlanViewModel {
  var form = SessionPlanForm() {
    didSet {
      guard form != oldValue else { return }
      results = nil
      path = []
      if searchFailure?.field?.hasChanged(from: oldValue, to: form) == true {
        searchFailure = nil
        showsSearchFailure = false
      }
    }
  }
  var path: [SessionPlanDestination] = []
  var showsSearchFailure = false
  private(set) var savedProfile: GamingProfile?
  private(set) var loadState = SessionPlanLoadState.awaitingLoad
  private(set) var searchFailure: SessionPlanSearchFailure?
  private(set) var results: TeammateResultsViewModel?

  private var hasInitialPlan = false
  private var hasUnsavedProfileChanges = false
  private let loadProfile: LoadGamingProfileUseCase
  private let findTeammates: FindCompatibleTeammatesUseCase

  init(loadProfile: LoadGamingProfileUseCase, findTeammates: FindCompatibleTeammatesUseCase) {
    self.loadProfile = loadProfile
    self.findTeammates = findTeammates
  }

  var canSearch: Bool { loadState == .ready && !hasUnsavedProfileChanges }

  func refreshProfile(hasUnsavedProfileChanges: Bool) {
    self.hasUnsavedProfileChanges = hasUnsavedProfileChanges
    if hasUnsavedProfileChanges {
      loadState = .unsavedProfileChanges
      results?.refresh(hasUnsavedProfileChanges: true)
      return
    }
    do {
      let profile = try loadProfile.execute()
      if profile != savedProfile {
        searchFailure = nil
        showsSearchFailure = false
      }
      savedProfile = profile
      if let profile {
        if !hasInitialPlan {
          form = SessionPlanForm(profile: profile)
          hasInitialPlan = true
        }
        loadState = .ready
      } else {
        loadState = .ownProfileRequired
      }
    } catch { loadState = .unavailable(error) }
    results?.refresh(hasUnsavedProfileChanges: false)
  }

  func search() {
    guard canSearch else { return }
    results = nil
    path = []
    let plan: SquadPlan
    do { plan = try form.makePlan() } catch {
      present(.form(error))
      return
    }
    do {
      let search = try findTeammates.execute(plan)
      savedProfile = search.organiser
      results = TeammateResultsViewModel(search: search, findTeammates: findTeammates)
      searchFailure = nil
      showsSearchFailure = false
      path = [.results]
    } catch { present(.search(error)) }
  }

  private func present(_ failure: SessionPlanSearchFailure) {
    searchFailure = failure
    showsSearchFailure = true
  }
}

nonisolated enum SessionPlanDestination: Hashable {
  case results
}

nonisolated enum SessionPlanLoadState: Equatable {
  case awaitingLoad
  case ready
  case ownProfileRequired
  case unsavedProfileChanges
  case unavailable(LoadGamingProfileError)
}

nonisolated enum SessionPlanSearchFailure: LocalizedError, Equatable {
  case form(SessionPlanFormError)
  case search(FindCompatibleTeammatesError)

  var field: SessionPlanField? {
    switch self {
    case .form(let reason): reason.field
    case .search(.outsideOwnAvailability): .playWindow
    case .search(.ownVoiceChatUnavailable): .voiceChat
    case .search(.ownProfileRequired), .search(.notebookUnavailable): nil
    }
  }

  var errorDescription: String? {
    switch self {
    case .form(let reason): reason.errorDescription
    case .search(let reason): reason.errorDescription
    }
  }

  func message(for field: SessionPlanField) -> String? {
    self.field == field ? errorDescription : nil
  }
}
