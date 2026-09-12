import Foundation

/// Records a teammate after permission is confirmed, rejecting self-records and duplicates.
@MainActor
struct SaveTeammateContactUseCase {
  let repository: any SquadNotebookRepository

  /// Opens contacts for editing while preserving exclusions saved by earlier versions.
  func loadSavedTeammates() throws(SaveTeammateContactError) -> [TeammateDirectoryEntry] {
    let notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }
    guard notebook.ownProfile != nil else { throw .ownProfileRequired }
    return notebook.contacts.map { contact in
      TeammateDirectoryEntry(
        contact: contact, isAvoided: notebook.avoidedPlayerIDs.contains(contact.id))
    }
  }

  /// Adds a contact or updates the supplied identity without replacing another teammate.
  func execute(
    _ draft: GamingProfileDraft,
    contactID: PlayerIdentifier? = nil,
    permissionConfirmed: Bool
  ) throws(SaveTeammateContactError) -> TeammateContact {
    guard permissionConfirmed else { throw .permissionRequired }
    var notebook: SquadNotebook
    do { notebook = try repository.loadNotebook() } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .notebookUnavailable }
    guard let organiser = notebook.ownProfile else { throw .ownProfileRequired }
    if contactID == organiser.id { throw .cannotRecordYourself }
    if let contactID, !notebook.contacts.contains(where: { $0.id == contactID }) {
      throw .contactNoLongerExists
    }

    let profile: GamingProfile
    do {
      profile = try GamingProfile(id: contactID ?? PlayerIdentifier(), draft: draft)
    } catch { throw .invalidProfile(error) }
    guard !profile.hasSameLocalIdentity(as: organiser) else { throw .cannotRecordYourself }
    guard
      !notebook.contacts.contains(where: {
        $0.id != profile.id && $0.profile.hasSameLocalIdentity(as: profile)
      })
    else { throw .duplicateTeammate }

    let contact = TeammateContact(profile: profile)
    if let index = notebook.contacts.firstIndex(where: { $0.id == contact.id }) {
      notebook.contacts[index] = contact
    } else {
      notebook.contacts.append(contact)
    }
    do { try repository.saveNotebook(notebook) } catch let failure as SquadNotebookAccessError {
      throw .notebookAccess(failure)
    } catch { throw .contactNotSaved }
    return contact
  }
}

nonisolated enum SaveTeammateContactError: LocalizedError, Equatable, Sendable {
  case permissionRequired
  case ownProfileRequired
  case invalidProfile(GamingProfileValidationError)
  case cannotRecordYourself
  case duplicateTeammate
  case contactNoLongerExists
  case notebookUnavailable
  case notebookAccess(SquadNotebookAccessError)
  case contactNotSaved

  var errorDescription: String? {
    switch self {
    case .permissionRequired:
      "Ask your teammate for permission to keep these details, then confirm permission before saving."
    case .ownProfileRequired:
      "Save your own profile before adding teammates."
    case .invalidProfile(let reason): reason.errorDescription
    case .cannotRecordYourself:
      "These details identify your own profile. Edit your profile instead of adding yourself as a teammate."
    case .duplicateTeammate:
      "This teammate name and server are already saved. Open the existing contact to update their details."
    case .contactNoLongerExists:
      "This teammate is no longer in your directory. Return to your teammate list before editing."
    case .notebookAccess(let reason): reason.errorDescription
    case .notebookUnavailable:
      "Your teammate directory could not be read. Reopen GameLink and try again; your saved data has not been replaced."
    case .contactNotSaved:
      "The teammate details were not saved. Your previous directory is unchanged. Keep your edits and try saving again."
    }
  }
}
