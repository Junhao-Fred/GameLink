import Foundation

@MainActor
struct LoadTeammateDirectoryUseCase {
  let repository: any SquadNotebookRepository

  func execute() throws(LoadTeammateDirectoryError) -> [TeammateDirectoryEntry] {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch { throw .directoryUnavailable }
    guard notebook.ownProfile != nil else { throw .ownProfileRequired }
    return notebook.contacts.map { contact in
      TeammateDirectoryEntry(
        contact: contact, isAvoided: notebook.avoidedPlayerIDs.contains(contact.id))
    }
  }
}

nonisolated enum LoadTeammateDirectoryError: LocalizedError, Equatable, Sendable {
  case ownProfileRequired
  case directoryUnavailable

  var errorDescription: String? {
    switch self {
    case .ownProfileRequired:
      "Save your own profile before adding or managing teammates."
    case .directoryUnavailable:
      "Your saved teammates could not be opened. Unlock your device and try again. Keep your saved data; do not reinstall GameLink."
    }
  }
}
