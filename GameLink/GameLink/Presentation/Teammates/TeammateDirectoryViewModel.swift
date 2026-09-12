import Foundation
import Observation

/// Owns one inline teammate draft and refreshes the directory after a successful save.
@MainActor
@Observable
final class TeammateDirectoryViewModel {
  private(set) var editor: TeammateContactEditorViewModel?
  var showsDiscardConfirmation = false
  private(set) var entries: [TeammateDirectoryEntry] = []
  private(set) var loadState = TeammateDirectoryLoadState.awaitingLoad
  private(set) var saveConfirmation: String?

  private let saveContact: SaveTeammateContactUseCase

  init(saveContact: SaveTeammateContactUseCase) {
    self.saveContact = saveContact
  }

  /// Reloads saved contacts without replacing an unfinished editing draft.
  func reload() {
    do {
      entries = try saveContact.loadSavedTeammates()
      loadState = .ready
    } catch {
      loadState = .unavailable(error)
    }
  }

  func beginAddingTeammate() {
    guard loadState == .ready, editor == nil else { return }
    saveConfirmation = nil
    editor = TeammateContactEditorViewModel(saveContact: saveContact)
  }

  func beginEditingTeammate(_ entry: TeammateDirectoryEntry) {
    guard loadState == .ready, editor == nil,
      let savedEntry = entries.first(where: { $0.id == entry.id })
    else { return }
    saveConfirmation = nil
    editor = TeammateContactEditorViewModel(saveContact: saveContact, contact: savedEntry.contact)
  }

  /// Keeps failed drafts open and closes the editor only after its details are saved.
  func saveEditor() {
    guard let editor, editor.save() else { return }
    self.editor = nil
    showsDiscardConfirmation = false
    reload()
    saveConfirmation = "Teammate saved on this device."
  }

  /// Requests confirmation before discarding any unsaved teammate details.
  func requestCancelEditing() {
    if editor?.hasUnsavedChanges == true {
      showsDiscardConfirmation = true
    } else {
      discardEditor()
    }
  }

  /// Discards only the in-memory draft; saved contacts remain unchanged.
  func discardEditor() {
    editor = nil
    showsDiscardConfirmation = false
  }
}

nonisolated enum TeammateDirectoryLoadState: Equatable {
  case awaitingLoad
  case ready
  case unavailable(SaveTeammateContactError)
}
