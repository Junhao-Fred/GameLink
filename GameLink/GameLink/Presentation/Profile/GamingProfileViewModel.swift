import Foundation
import Observation

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

  private let loadProfile: LoadGamingProfileUseCase
  private let saveProfile: SaveGamingProfileUseCase

  init(loadProfile: LoadGamingProfileUseCase, saveProfile: SaveGamingProfileUseCase) {
    self.loadProfile = loadProfile
    self.saveProfile = saveProfile
  }

  var hasUnsavedChanges: Bool { form != GamingProfileForm(profile: savedProfile) }

  var canSave: Bool {
    loadState == .ready && (savedProfile == nil || hasUnsavedChanges)
  }

  func loadIfNeeded() {
    guard loadState != .ready else { return }
    do {
      savedProfile = try loadProfile.execute()
      form = GamingProfileForm(profile: savedProfile)
      saveFailure = nil
      showsSaveFailure = false
      loadState = .ready
    } catch { loadState = .unavailable(error) }
  }

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
    let affectedFieldChanged: Bool =
      switch saveFailure?.field {
      case .playerName:
        form.gamerTag != previousForm.gamerTag || form.server != previousForm.server
      case .server: form.server != previousForm.server
      case .role: form.preferredRole != previousForm.preferredRole
      case .playDay: form.playDay != previousForm.playDay
      case .availability:
        form.startMinute != previousForm.startMinute
          || form.durationMinutes != previousForm.durationMinutes
      case nil: false
      }
    if affectedFieldChanged {
      saveFailure = nil
      showsSaveFailure = false
    }
  }
}

nonisolated enum GamingProfileLoadState: Equatable {
  case awaitingLoad
  case ready
  case unavailable(LoadGamingProfileError)
}

nonisolated enum GamingProfileSaveFailure: LocalizedError, Equatable {
  case form(GamingProfileFormError)
  case profile(SaveGamingProfileError)

  var field: GamingProfileField? {
    switch self {
    case .form(let reason): reason.field
    case .profile(.invalidProfile), .profile(.nameUsedByTeammate): .playerName
    case .profile(.notebookUnavailable), .profile(.profileNotSaved): nil
    }
  }

  var errorDescription: String? {
    switch self {
    case .form(let reason): reason.errorDescription
    case .profile(let reason): reason.errorDescription
    }
  }

  func message(for field: GamingProfileField) -> String? {
    self.field == field ? errorDescription : nil
  }
}
