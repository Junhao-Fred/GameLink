import Foundation

/// A teammate saved after the organiser confirms permission.
/// Each add or edit needs fresh permission; duplicate profiles are rejected.
nonisolated struct TeammateContact: Identifiable, Equatable, Sendable {
  let profile: GamingProfile
  var id: PlayerIdentifier { profile.id }
}

/// The requested session time, position and voice preference.
/// The whole session must fit the organiser's availability; required voice chat must suit both players.
nonisolated struct SquadPlan: Equatable, Sendable {
  let playWindow: WeeklyPlayWindow
  let neededRole: PreferredRole
  let requiresVoiceChat: Bool

}

/// A compatible teammate and at least 30 shared minutes.
/// Server and position must match; shared time may be shorter than the planned session.
nonisolated struct TeammateMatch: Identifiable, Equatable, Sendable {
  let teammate: GamingProfile
  let sharedWindow: WeeklyPlayWindow
  var id: PlayerIdentifier { teammate.id }
}

/// The organiser, plan and ranked matches from one search.
/// Excludes avoided players; sorts by shared minutes, then name and ID.
/// Profile changes require a new search before preparing a proposal.
nonisolated struct SquadSearch: Equatable, Sendable {
  let organiser: GamingProfile
  let plan: SquadPlan
  let matches: [TeammateMatch]
}

/// An unconfirmed session suggestion for two players.
/// Rechecks saved details and includes only their shared time.
/// Players confirm the date in chat; sharing does not prove delivery or acceptance.
nonisolated struct SquadProposal: Equatable, Sendable {
  let organiser: GamingProfile
  let teammate: GamingProfile
  let sharedWindow: WeeklyPlayWindow
  let requiresVoiceChat: Bool

  /// Share text without internal IDs or private exclusions.
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
