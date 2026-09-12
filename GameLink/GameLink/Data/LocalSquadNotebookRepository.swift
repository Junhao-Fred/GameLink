import Foundation

/// Stores one validated squad notebook as JSON in the app's private local storage.
@MainActor
final class LocalSquadNotebookRepository: SquadNotebookRepository {
  let fileURL: URL
  private var hasSeenSavedFile = false

  init(fileURL: URL) throws(SquadNotebookAccessError) {
    guard fileURL.isFileURL else { throw .notebookLocationUnavailable }
    self.fileURL = fileURL
  }

  /// Resolves the app's notebook location without embedding a development-machine path.
  static func applicationSupport() throws(SquadNotebookAccessError) -> LocalSquadNotebookRepository
  {
    do {
      let directory = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
      return try LocalSquadNotebookRepository(
        fileURL: directory.appending(path: "GameLink", directoryHint: .isDirectory)
          .appending(path: "squad-notebook.json", directoryHint: .notDirectory))
    } catch { throw .notebookLocationUnavailable }
  }

  /// Reads and validates saved details, distinguishing first launch from a missing known file.
  func loadNotebook() throws(SquadNotebookAccessError) -> SquadNotebook {
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
        throw SquadNotebookAccessError.unsupportedStorageVersion
      }
      return try JSONDecoder().decode(SavedSquadNotebook.self, from: contents).restoredNotebook()
    } catch let failure as SquadNotebookAccessError {
      throw failure
    } catch { throw .savedDetailsInvalid }
  }

  /// Validates both the replacement and existing data before an atomic file write.
  func saveNotebook(_ notebook: SquadNotebook) throws(SquadNotebookAccessError) {
    let savedNotebook = SavedSquadNotebook(notebook: notebook)
    do { _ = try savedNotebook.restoredNotebook() } catch { throw .savedDetailsInvalid }
    // Unreadable or unsupported saved data must not be overwritten by a new notebook.
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

/// Reads the format version before attempting to decode its profile fields.
nonisolated private struct SavedNotebookVersion: Decodable {
  let schemaVersion: Int
}
