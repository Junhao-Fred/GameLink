import Foundation

/// A local player ID that stays the same when details change.
nonisolated struct PlayerIdentifier: Hashable, Sendable {
  let rawValue: UUID

  init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

/// A supported game server; teammates must use the same server.
nonisolated enum GameServer: String, CaseIterable, Sendable {
  case oceania = "Oceania"
  case europeWest = "Europe West"
  case northAmerica = "North America"
}

/// The League of Legends position a player offers or a session needs.
nonisolated enum PreferredRole: String, CaseIterable, Sendable {
  case top = "Top"
  case jungle = "Jungle"
  case middle = "Middle"
  case bottom = "Bottom"
  case support = "Support"
}

/// Player details awaiting validation.
/// Names are trimmed and must have 1...40 characters with no control characters.
nonisolated struct GamingProfileDraft: Equatable, Sendable {
  var gamerTag: String
  var server: GameServer
  var preferredRole: PreferredRole
  var availability: WeeklyPlayWindow
  var usesVoiceChat: Bool
}

/// A player's self-reported preferences and weekly availability.
/// Names have 1...40 characters with no control characters; identity is not verified.
nonisolated struct GamingProfile: Identifiable, Equatable, Sendable {
  let id: PlayerIdentifier
  let gamerTag: String
  let server: GameServer
  let preferredRole: PreferredRole
  let availability: WeeklyPlayWindow
  let usesVoiceChat: Bool

  /// Trims and validates the name while keeping the supplied player ID.
  init(id: PlayerIdentifier, draft: GamingProfileDraft) throws(GamingProfileValidationError) {
    let name = draft.gamerTag.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw .missingPlayerName }
    guard name.count <= 40 else { throw .playerNameTooLong }
    guard name.rangeOfCharacter(from: .controlCharacters) == nil else {
      throw .playerNameContainsControlCharacters
    }
    self.id = id
    gamerTag = name
    server = draft.server
    preferredRole = draft.preferredRole
    availability = draft.availability
    usesVoiceChat = draft.usesVoiceChat
  }

  /// Compares server and player name, ignoring letter case.
  func hasSameLocalIdentity(as other: GamingProfile) -> Bool {
    server == other.server
      && gamerTag.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        == other.gamerTag.folding(
          options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
  }
}

/// Player-name errors with correction guidance.
nonisolated enum GamingProfileValidationError: LocalizedError, Equatable, Sendable {
  case missingPlayerName
  case playerNameTooLong
  case playerNameContainsControlCharacters

  var errorDescription: String? {
    switch self {
    case .missingPlayerName:
      "Enter a player name before saving."
    case .playerNameTooLong:
      "Use a player name of 40 characters or fewer, then save again."
    case .playerNameContainsControlCharacters:
      "Keep the player name on one line without tabs or control characters, then save again."
    }
  }
}
