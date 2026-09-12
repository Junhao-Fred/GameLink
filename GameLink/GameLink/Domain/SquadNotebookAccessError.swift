import Foundation

/// Reasons saved squad details cannot be used, with guidance that preserves the original notebook.
/// Business operations carry these failures to players without exposing JSON or file-system errors.
nonisolated enum SquadNotebookAccessError: LocalizedError, Equatable, Sendable {
  case notebookLocationUnavailable
  case savedDetailsUnreadable
  case savedDetailsInvalid
  case unsupportedStorageVersion
  case savedDetailsMissing
  case changesNotSaved

  var errorDescription: String? {
    switch self {
    case .notebookLocationUnavailable:
      "GameLink could not open its private storage. Reopen the app and try again before entering squad details."
    case .savedDetailsUnreadable:
      "Your saved squad details could not be opened. Unlock your device and reopen GameLink. Do not delete your saved data."
    case .savedDetailsInvalid:
      "Your saved squad details are incomplete or inconsistent. Keep the original file and restore a valid device backup before making changes."
    case .unsupportedStorageVersion:
      "These squad details use a storage format this version of GameLink cannot open. Use a compatible app version before making changes. Your file has not been replaced."
    case .savedDetailsMissing:
      "Your previously opened squad details are no longer available. Restore the saved file before making changes; GameLink has not created an empty replacement."
    case .changesNotSaved:
      "Your squad changes were not saved. Keep your edits, check available device storage, and try again. Your previous saved details are unchanged."
    }
  }
}
