import Foundation

@MainActor
struct SaveGamingProfileUseCase {
  let repository: any SquadNotebookRepository

  func execute(_ draft: GamingProfileDraft) throws(SaveGamingProfileError) -> GamingProfile {
    var notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch { throw .notebookUnavailable }

    let profile: GamingProfile
    do {
      profile = try GamingProfile(id: notebook.ownProfile?.id ?? PlayerIdentifier(), draft: draft)
    } catch { throw .invalidProfile(error) }

    guard !notebook.contacts.contains(where: { $0.profile.hasSameLocalIdentity(as: profile) })
    else {
      throw .nameUsedByTeammate
    }
    notebook.ownProfile = profile
    do { try repository.saveNotebook(notebook) } catch { throw .profileNotSaved }
    return profile
  }
}

nonisolated enum SaveGamingProfileError: LocalizedError, Equatable, Sendable {
  case invalidProfile(GamingProfileValidationError)
  case nameUsedByTeammate
  case notebookUnavailable
  case profileNotSaved

  var errorDescription: String? {
    switch self {
    case .invalidProfile(let reason): reason.errorDescription
    case .nameUsedByTeammate:
      "This name and server are already in your teammate list. Check the teammate details before saving your profile."
    case .notebookUnavailable:
      "Your saved squad details could not be read. Reopen GameLink and try again; do not replace your saved data."
    case .profileNotSaved:
      "Your profile changes were not saved. Your previous details are unchanged. Try saving again."
    }
  }
}
