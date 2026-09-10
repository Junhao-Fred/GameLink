import Foundation
import Observation

@MainActor
@Observable
final class TeammateDirectoryViewModel {
  var editor: TeammateContactEditorViewModel?
  var showsAvoidanceFailure = false
  private(set) var entries: [TeammateDirectoryEntry] = []
  private(set) var loadState = TeammateDirectoryLoadState.awaitingLoad
  private(set) var avoidanceFailure: SetTeammateAvoidanceError?
  private(set) var preferenceConfirmation: String?

  private let loadDirectory: LoadTeammateDirectoryUseCase
  private let saveContact: SaveTeammateContactUseCase
  private let setAvoidance: SetTeammateAvoidanceUseCase

  init(
    loadDirectory: LoadTeammateDirectoryUseCase,
    saveContact: SaveTeammateContactUseCase,
    setAvoidance: SetTeammateAvoidanceUseCase
  ) {
    self.loadDirectory = loadDirectory
    self.saveContact = saveContact
    self.setAvoidance = setAvoidance
  }

  func reload() {
    do {
      entries = try loadDirectory.execute()
      loadState = .ready
    } catch {
      loadState = .unavailable(error)
    }
  }

  func beginAddingTeammate() {
    guard loadState == .ready else { return }
    preferenceConfirmation = nil
    editor = TeammateContactEditorViewModel(saveContact: saveContact)
  }

  func beginEditingTeammate(_ entry: TeammateDirectoryEntry) {
    guard loadState == .ready,
      let savedEntry = entries.first(where: { $0.id == entry.id })
    else { return }
    preferenceConfirmation = nil
    editor = TeammateContactEditorViewModel(saveContact: saveContact, contact: savedEntry.contact)
  }

  func changeAvoidance(for entry: TeammateDirectoryEntry) {
    guard loadState == .ready else { return }
    let isAvoided = !entry.isAvoided
    preferenceConfirmation = nil
    do {
      try setAvoidance.execute(teammateID: entry.id, isAvoided: isAvoided)
      avoidanceFailure = nil
      showsAvoidanceFailure = false
      reload()
      preferenceConfirmation =
        isAvoided
        ? "\(entry.contact.profile.gamerTag) will be excluded from your searches."
        : "\(entry.contact.profile.gamerTag) can appear in your searches again."
    } catch {
      avoidanceFailure = error
      showsAvoidanceFailure = true
    }
  }
}

nonisolated enum TeammateDirectoryLoadState: Equatable {
  case awaitingLoad
  case ready
  case unavailable(LoadTeammateDirectoryError)
}
