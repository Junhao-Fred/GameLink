import Foundation

nonisolated struct TeammateContact: Identifiable, Equatable, Sendable {
  let profile: GamingProfile
  var id: PlayerIdentifier { profile.id }
}

nonisolated struct SquadPlan: Equatable, Sendable {
  let playWindow: WeeklyPlayWindow
  let neededRole: PreferredRole
  let requiresVoiceChat: Bool

  func match(for contact: TeammateContact, organiser: GamingProfile) -> TeammateMatch? {
    let teammate = contact.profile
    guard teammate.id != organiser.id,
      !teammate.hasSameLocalIdentity(as: organiser),
      teammate.server == organiser.server,
      teammate.preferredRole == neededRole,
      !requiresVoiceChat || teammate.usesVoiceChat,
      let sharedWindow = playWindow.sharedWindow(with: teammate.availability)
    else { return nil }
    return TeammateMatch(teammate: teammate, sharedWindow: sharedWindow)
  }
}

nonisolated struct TeammateMatch: Identifiable, Equatable, Sendable {
  let teammate: GamingProfile
  let sharedWindow: WeeklyPlayWindow
  var id: PlayerIdentifier { teammate.id }
}

nonisolated struct SquadSearch: Equatable, Sendable {
  let organiser: GamingProfile
  let plan: SquadPlan
  let matches: [TeammateMatch]
}

nonisolated struct SquadProposal: Identifiable, Equatable, Sendable {
  let id: UUID
  let organiser: GamingProfile
  let teammate: GamingProfile
  let sharedWindow: WeeklyPlayWindow
  let requiresVoiceChat: Bool

  var shareText: String {
    """
    GameLink session proposal - not confirmed
    From: \(organiser.gamerTag)
    To: \(teammate.gamerTag)
    Game: League of Legends
    Server: \(organiser.server.rawValue)
    Needed role: \(teammate.preferredRole.rawValue)
    Shared time: \(sharedWindow.summary)
    Voice chat: \(requiresVoiceChat ? "Required" : "Optional")

    Please confirm the exact date and this time in our chat. This proposal is not a booking.
    """
  }
}
