import Foundation

nonisolated struct PlayerIdentifier: Hashable, Sendable {
  let rawValue: UUID

  init(rawValue: UUID = UUID()) {
    self.rawValue = rawValue
  }
}

nonisolated enum GameServer: String, CaseIterable, Sendable {
  case oceania = "Oceania"
  case europeWest = "Europe West"
  case northAmerica = "North America"
}

nonisolated enum PreferredRole: String, CaseIterable, Sendable {
  case top = "Top"
  case jungle = "Jungle"
  case middle = "Middle"
  case bottom = "Bottom"
  case support = "Support"
}

nonisolated struct GamingProfileDraft: Equatable, Sendable {
  var gamerTag: String
  var server: GameServer
  var preferredRole: PreferredRole
  var availability: WeeklyPlayWindow
  var usesVoiceChat: Bool
}

nonisolated struct GamingProfile: Identifiable, Equatable, Sendable {
  let id: PlayerIdentifier
  let gamerTag: String
  let server: GameServer
  let preferredRole: PreferredRole
  let availability: WeeklyPlayWindow
  let usesVoiceChat: Bool

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

  func hasSameLocalIdentity(as other: GamingProfile) -> Bool {
    server == other.server
      && gamerTag.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        == other.gamerTag.folding(
          options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
  }
}

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
