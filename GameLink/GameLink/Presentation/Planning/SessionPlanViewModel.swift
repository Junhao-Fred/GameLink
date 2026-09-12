import Foundation
import Observation

/// Owns the session draft, matching results and selected teammate across the four tabs.
@MainActor
@Observable
final class SessionPlanViewModel {
  var selectedTab = GameLinkTab.plan
  var form = SessionPlanForm() {
    didSet {
      guard form != oldValue else { return }
      // Results and selected details belong to the previous session conditions.
      results = nil
      selectedTeammate = nil
      if searchFailure?.field?.hasChanged(from: oldValue, to: form) == true {
        searchFailure = nil
        showsSearchFailure = false
      }
    }
  }
  var showsSearchFailure = false
  private(set) var savedProfile: GamingProfile?
  private(set) var loadState = SessionPlanLoadState.awaitingLoad
  private(set) var searchFailure: SessionPlanSearchFailure?
  private(set) var results: TeammateResultsViewModel?
  private(set) var selectedTeammate: TeammateDetailsViewModel?

  private var hasInitialPlan = false
  private var hasUnsavedProfileChanges = false
  private let findTeammates: FindCompatibleTeammatesUseCase
  private let prepareProposal: PrepareSquadProposalUseCase

  init(
    findTeammates: FindCompatibleTeammatesUseCase,
    prepareProposal: PrepareSquadProposalUseCase
  ) {
    self.findTeammates = findTeammates
    self.prepareProposal = prepareProposal
  }

  var canSearch: Bool { loadState == .ready && !hasUnsavedProfileChanges }

  /// Rechecks saved context while preventing searches based on unfinished profile edits.
  func refreshProfile(hasUnsavedProfileChanges: Bool) {
    self.hasUnsavedProfileChanges = hasUnsavedProfileChanges
    if hasUnsavedProfileChanges {
      loadState = .unsavedProfileChanges
      results?.refresh(hasUnsavedProfileChanges: true)
      selectedTeammate?.refresh(hasUnsavedProfileChanges: true)
      return
    }
    do {
      let profile = try findTeammates.loadOrganiser()
      if profile != savedProfile {
        searchFailure = nil
        showsSearchFailure = false
      }
      savedProfile = profile
      if !hasInitialPlan {
        form = SessionPlanForm(profile: profile)
        hasInitialPlan = true
      }
      loadState = .ready
    } catch {
      if error == .ownProfileRequired {
        savedProfile = nil
        loadState = .ownProfileRequired
      } else {
        loadState = .unavailable(error)
      }
    }
    results?.refresh(hasUnsavedProfileChanges: false)
    selectedTeammate?.refresh(hasUnsavedProfileChanges: false)
  }

  /// Searches the current draft and opens Matches only after a successful validation.
  func search() {
    guard canSearch else { return }
    results = nil
    selectedTeammate = nil
    selectedTab = .plan
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
      selectedTab = .matches
    } catch { present(.search(error)) }
  }

  private func present(_ failure: SessionPlanSearchFailure) {
    searchFailure = failure
    showsSearchFailure = true
  }

  /// Opens Details only for a teammate present in the currently available search results.
  func openTeammate(_ teammateID: PlayerIdentifier) {
    guard canSearch, case .available(let search) = results?.state,
      search.matches.contains(where: { $0.id == teammateID })
    else { return }
    selectedTeammate = TeammateDetailsViewModel(
      teammateID: teammateID, search: search, prepareProposal: prepareProposal)
    selectedTab = .details
  }

  /// Clears the selected detail and rechecks matches while retaining the session draft.
  func returnToResults() {
    selectedTeammate = nil
    selectedTab = .matches
    refreshProfile(hasUnsavedProfileChanges: hasUnsavedProfileChanges)
  }
}

nonisolated enum SessionPlanLoadState: Equatable {
  case awaitingLoad
  case ready
  case ownProfileRequired
  case unsavedProfileChanges
  case unavailable(FindCompatibleTeammatesError)
}

nonisolated enum SessionPlanSearchFailure: LocalizedError, Equatable {
  case form(SessionPlanFormError)
  case search(FindCompatibleTeammatesError)

  var field: SessionPlanField? {
    switch self {
    case .form(let reason): reason.field
    case .search(.outsideOwnAvailability): .playWindow
    case .search(.ownVoiceChatUnavailable): .voiceChat
    case .search(.ownProfileRequired), .search(.notebookUnavailable), .search(.notebookAccess): nil
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
