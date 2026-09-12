import Foundation

/// The notebook's versioned JSON format, separate from domain models.
nonisolated struct SavedSquadNotebook: Codable {
  let schemaVersion: Int
  let ownProfile: SavedGamingProfile?
  let contacts: [SavedGamingProfile]
  let avoidedPlayerIDs: [UUID]

  init(notebook: SquadNotebook) {
    schemaVersion = 1
    ownProfile = notebook.ownProfile.map(SavedGamingProfile.init)
    contacts = notebook.contacts.map { SavedGamingProfile(profile: $0.profile) }
    avoidedPlayerIDs = notebook.avoidedPlayerIDs.map(\.rawValue).sorted {
      $0.uuidString < $1.uuidString
    }
  }

  /// Restores the notebook after checking profiles, duplicates and exclusions.
  func restoredNotebook() throws -> SquadNotebook {
    guard schemaVersion == 1 else { throw SquadNotebookAccessError.unsupportedStorageVersion }
    let organiser = try ownProfile?.restoredProfile()
    let teammates = try contacts.map { TeammateContact(profile: try $0.restoredProfile()) }
    let avoidedIDs = Set(avoidedPlayerIDs.map { PlayerIdentifier(rawValue: $0) })
    let teammateIDs = Set(teammates.map(\.id))
    guard teammates.count == teammateIDs.count,
      avoidedIDs.count == avoidedPlayerIDs.count,
      avoidedIDs.isSubset(of: teammateIDs),
      organiser != nil || teammates.isEmpty
    else { throw SquadNotebookAccessError.savedDetailsInvalid }

    var knownProfiles = organiser.map { [$0] } ?? []
    for teammate in teammates {
      guard
        !knownProfiles.contains(where: {
          $0.id == teammate.id || $0.hasSameLocalIdentity(as: teammate.profile)
        })
      else { throw SquadNotebookAccessError.savedDetailsInvalid }
      knownProfiles.append(teammate.profile)
    }
    return SquadNotebook(ownProfile: organiser, contacts: teammates, avoidedPlayerIDs: avoidedIDs)
  }
}

/// Saved player fields that must pass validation when loaded.
nonisolated struct SavedGamingProfile: Codable {
  let playerID: UUID
  let gamerTag: String
  let server: String
  let preferredRole: String
  let availability: SavedWeeklyPlayWindow
  let usesVoiceChat: Bool

  init(profile: GamingProfile) {
    playerID = profile.id.rawValue
    gamerTag = profile.gamerTag
    server = profile.server.rawValue
    preferredRole = profile.preferredRole.rawValue
    availability = SavedWeeklyPlayWindow(window: profile.availability)
    usesVoiceChat = profile.usesVoiceChat
  }

  /// Rejects unknown preferences or invalid names without changing saved data.
  func restoredProfile() throws -> GamingProfile {
    guard let server = GameServer(rawValue: server),
      let role = PreferredRole(rawValue: preferredRole)
    else { throw SquadNotebookAccessError.savedDetailsInvalid }
    let draft = GamingProfileDraft(
      gamerTag: gamerTag, server: server, preferredRole: role,
      availability: try availability.restoredWindow(), usesVoiceChat: usesVoiceChat)
    let profile = try GamingProfile(id: PlayerIdentifier(rawValue: playerID), draft: draft)
    guard profile.gamerTag == gamerTag else { throw SquadNotebookAccessError.savedDetailsInvalid }
    return profile
  }
}

/// Saved availability with its Sydney time-zone identifier.
nonisolated struct SavedWeeklyPlayWindow: Codable {
  let day: String
  let startMinute: Int
  let durationMinutes: Int
  let timeZoneIdentifier: String

  init(window: WeeklyPlayWindow) {
    day = window.day.rawValue
    startMinute = window.startMinute
    durationMinutes = window.durationMinutes
    timeZoneIdentifier = WeeklyPlayWindow.timeZoneIdentifier
  }

  /// Restores a valid window only when the saved time zone is supported.
  func restoredWindow() throws -> WeeklyPlayWindow {
    guard let day = PlayDay(rawValue: day),
      timeZoneIdentifier == WeeklyPlayWindow.timeZoneIdentifier
    else { throw SquadNotebookAccessError.savedDetailsInvalid }
    return try WeeklyPlayWindow(
      day: day, startMinute: startMinute, durationMinutes: durationMinutes)
  }
}
