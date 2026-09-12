import Foundation
import Observation

/// Manages one teammate draft and reloads the directory after saving.
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

  /// Reloads teammates without replacing an unfinished draft.
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

  /// Closes the editor only after saving; failures keep it open.
  func saveEditor() {
    guard let editor, editor.save() else { return }
    self.editor = nil
    showsDiscardConfirmation = false
    reload()
    saveConfirmation = "Teammate saved on this device."
  }

  /// Asks before discarding unsaved teammate changes.
  func requestCancelEditing() {
    if editor?.hasUnsavedChanges == true {
      showsDiscardConfirmation = true
    } else {
      discardEditor()
    }
  }

  /// Discards the draft without changing saved teammates.
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
