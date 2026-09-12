import Foundation
import Observation

/// Keeps the profile draft and shows save results without losing edits.
@MainActor
@Observable
final class GamingProfileViewModel {
  var form = GamingProfileForm() {
    didSet {
      showsSaveConfirmation = false
      clearFailureAfterEditing(oldValue)
    }
  }
  var showsSaveFailure = false
  private(set) var loadState = GamingProfileLoadState.awaitingLoad
  private(set) var savedProfile: GamingProfile?
  private(set) var saveFailure: GamingProfileSaveFailure?
  private(set) var showsSaveConfirmation = false

  private let saveProfile: SaveGamingProfileUseCase

  init(saveProfile: SaveGamingProfileUseCase) {
    self.saveProfile = saveProfile
  }

  var hasUnsavedChanges: Bool { form != GamingProfileForm(profile: savedProfile) }

  var canSave: Bool {
    loadState == .ready && (savedProfile == nil || hasUnsavedChanges)
  }

  /// Whether the visible profile matches saved details and can be used to manage teammates.
  var canManageTeammates: Bool {
    loadState == .ready && savedProfile != nil && !hasUnsavedChanges
  }

  /// Loads until successful, then keeps any unsaved edits when revisiting Profile.
  func loadIfNeeded() {
    guard loadState != .ready else { return }
    do {
      savedProfile = try saveProfile.loadSavedProfile()
      form = GamingProfileForm(profile: savedProfile)
      saveFailure = nil
      showsSaveFailure = false
      loadState = .ready
    } catch { loadState = .unavailable(error) }
  }

  /// Validates and saves the form; updates saved state only on success.
  func save() {
    guard canSave else { return }
    let draft: GamingProfileDraft
    do { draft = try form.makeDraft() } catch {
      present(.form(error))
      return
    }
    do {
      let profile = try saveProfile.execute(draft)
      savedProfile = profile
      form = GamingProfileForm(profile: profile)
      saveFailure = nil
      showsSaveFailure = false
      showsSaveConfirmation = true
    } catch { present(.profile(error)) }
  }

  private func present(_ failure: GamingProfileSaveFailure) {
    saveFailure = failure
    showsSaveConfirmation = false
    showsSaveFailure = true
  }

  private func clearFailureAfterEditing(_ previousForm: GamingProfileForm) {
    if saveFailure?.field?.hasChanged(from: previousForm, to: form) == true {
      saveFailure = nil
      showsSaveFailure = false
    }
  }
}

nonisolated enum GamingProfileLoadState: Equatable {
  case awaitingLoad
  case ready
  case unavailable(SaveGamingProfileError)
}

nonisolated enum GamingProfileSaveFailure: LocalizedError, Equatable {
  case form(GamingProfileFormError)
  case profile(SaveGamingProfileError)

  var field: GamingProfileField? {
    switch self {
    case .form(let reason): reason.field
    case .profile(.invalidProfile), .profile(.nameUsedByTeammate): .playerName
    case .profile(.notebookUnavailable), .profile(.profileNotSaved), .profile(.notebookAccess): nil
    }
  }

  var errorDescription: String? {
    switch self {
    case .form(let reason): reason.errorDescription
    case .profile(let reason): reason.errorDescription
    }
  }
}
