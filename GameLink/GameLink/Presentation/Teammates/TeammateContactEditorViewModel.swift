import Foundation
import Observation

/// Owns one teammate-editing draft and requires permission confirmation for every edit session.
@MainActor
@Observable
final class TeammateContactEditorViewModel: Identifiable {
  let id = UUID()
  let contactID: PlayerIdentifier?
  var form: GamingProfileForm {
    didSet {
      if saveFailure?.field?.hasChanged(from: oldValue, to: form) == true {
        saveFailure = nil
        showsSaveFailure = false
      }
    }
  }
  var permissionConfirmed = false {
    didSet {
      if permissionConfirmed && saveFailure == .contact(.permissionRequired) {
        saveFailure = nil
        showsSaveFailure = false
      }
    }
  }
  var showsSaveFailure = false
  private(set) var saveFailure: TeammateContactSaveFailure?
  private(set) var savedContact: TeammateContact?

  private let initialForm: GamingProfileForm
  private let saveContact: SaveTeammateContactUseCase

  init(saveContact: SaveTeammateContactUseCase, contact: TeammateContact? = nil) {
    self.saveContact = saveContact
    contactID = contact?.id
    initialForm = GamingProfileForm(profile: contact?.profile)
    form = initialForm
  }

  var hasUnsavedChanges: Bool {
    savedContact == nil && (form != initialForm || permissionConfirmed)
  }

  /// Returns true only after saving; failures leave the entered teammate details available.
  @discardableResult
  func save() -> Bool {
    guard savedContact == nil else { return false }
    guard permissionConfirmed else {
      present(.contact(.permissionRequired))
      return false
    }
    let draft: GamingProfileDraft
    do { draft = try form.makeDraft() } catch {
      present(.form(error))
      return false
    }
    do {
      savedContact = try saveContact.execute(
        draft, contactID: contactID, permissionConfirmed: permissionConfirmed)
      saveFailure = nil
      showsSaveFailure = false
      return true
    } catch {
      present(.contact(error))
      return false
    }
  }

  private func present(_ failure: TeammateContactSaveFailure) {
    saveFailure = failure
    showsSaveFailure = true
  }
}

nonisolated enum TeammateContactSaveFailure: LocalizedError, Equatable {
  case form(GamingProfileFormError)
  case contact(SaveTeammateContactError)

  var field: GamingProfileField? {
    switch self {
    case .form(let reason): reason.field
    case .contact(.invalidProfile), .contact(.duplicateTeammate), .contact(.cannotRecordYourself):
      .playerName
    case .contact: nil
    }
  }

  var errorDescription: String? {
    switch self {
    case .form(let reason): reason.errorDescription
    case .contact(let reason): reason.errorDescription
    }
  }
}
