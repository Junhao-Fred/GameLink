import Foundation

/// Saves the organiser's profile while preserving identity and preventing local duplicates.
@MainActor
struct SaveGamingProfileUseCase {
  let repository: any SquadNotebookRepository

  /// Opens the saved profile for editing; nil means no profile has been saved yet.
  func loadSavedProfile() throws(SaveGamingProfileError) -> GamingProfile? {
    do { return try repository.loadNotebook().ownProfile } catch let failure
      as SquadNotebookAccessError
    {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }
  }

  /// Validates and stores the draft, returning the profile only after the save succeeds.
  func execute(_ draft: GamingProfileDraft) throws(SaveGamingProfileError) -> GamingProfile {
    var notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }

    let profile: GamingProfile
    do {
      profile = try GamingProfile(id: notebook.ownProfile?.id ?? PlayerIdentifier(), draft: draft)
    } catch { throw .invalidProfile(error) }

    guard !notebook.contacts.contains(where: { $0.profile.hasSameLocalIdentity(as: profile) })
    else {
      throw .nameUsedByTeammate
    }
    notebook.ownProfile = profile
    do { try repository.saveNotebook(notebook) } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .profileNotSaved }
    return profile
  }
}

nonisolated enum SaveGamingProfileError: LocalizedError, Equatable, Sendable {
  case invalidProfile(GamingProfileValidationError)
  case nameUsedByTeammate
  case notebookUnavailable
  case notebookAccess(SquadNotebookAccessError)
  case profileNotSaved

  var errorDescription: String? {
    switch self {
    case .invalidProfile(let reason): reason.errorDescription
    case .nameUsedByTeammate:
      "This name and server are already in your teammate list. Check the teammate details before saving your profile."
    case .notebookAccess(let reason): reason.errorDescription
    case .notebookUnavailable:
      "Your saved profile could not be opened. Unlock your device and try again. Keep your saved data; do not reinstall GameLink."
    case .profileNotSaved:
      "Your profile changes were not saved. Your previous details are unchanged. Try saving again."
    }
  }
}
