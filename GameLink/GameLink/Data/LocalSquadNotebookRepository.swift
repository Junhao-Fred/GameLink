import Foundation

@MainActor
final class LocalSquadNotebookRepository: SquadNotebookRepository {
  let fileURL: URL
  private var hasSeenSavedFile = false

  init(fileURL: URL) throws(SquadNotebookStorageError) {
    guard fileURL.isFileURL else { throw .notebookLocationUnavailable }
    self.fileURL = fileURL
  }

  static func applicationSupport() throws(SquadNotebookStorageError) -> LocalSquadNotebookRepository
  {
    do {
      let directory = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
      return try LocalSquadNotebookRepository(
        fileURL: directory.appending(path: "GameLink", directoryHint: .isDirectory)
          .appending(path: "squad-notebook.json", directoryHint: .notDirectory))
    } catch { throw .notebookLocationUnavailable }
  }

  func loadNotebook() throws(SquadNotebookStorageError) -> SquadNotebook {
    let contents: Data
    do {
      contents = try Data(contentsOf: fileURL)
    } catch {
      let failure = error as NSError
      guard failure.domain == NSCocoaErrorDomain, failure.code == NSFileReadNoSuchFileError
      else { throw .savedDetailsUnreadable }
      guard !hasSeenSavedFile else { throw .savedDetailsMissing }
      return SquadNotebook()
    }
    hasSeenSavedFile = true
    do {
      let version = try JSONDecoder().decode(SavedNotebookVersion.self, from: contents)
      guard version.schemaVersion == 1 else {
        throw SquadNotebookStorageError.unsupportedStorageVersion
      }
      return try JSONDecoder().decode(SavedSquadNotebook.self, from: contents).restoredNotebook()
    } catch let failure as SquadNotebookStorageError {
      throw failure
    } catch { throw .savedDetailsInvalid }
  }

  func saveNotebook(_ notebook: SquadNotebook) throws(SquadNotebookStorageError) {
    let savedNotebook = SavedSquadNotebook(notebook: notebook)
    do { _ = try savedNotebook.restoredNotebook() } catch { throw .savedDetailsInvalid }
    _ = try loadNotebook()
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let contents = try encoder.encode(savedNotebook)
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try contents.write(to: fileURL, options: [.atomic, .completeFileProtection])
    } catch { throw .changesNotSaved }
    hasSeenSavedFile = true
  }
}

nonisolated private struct SavedNotebookVersion: Decodable {
  let schemaVersion: Int
}
