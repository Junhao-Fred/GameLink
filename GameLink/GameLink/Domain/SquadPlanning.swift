import Foundation

/// A teammate's locally recorded profile, saved after the organiser confirms permission.
/// Adding or editing requires fresh permission; a contact cannot duplicate the organiser or another teammate.
nonisolated struct TeammateContact: Identifiable, Equatable, Sendable {
  let profile: GamingProfile
  var id: PlayerIdentifier { profile.id }
}

/// The organiser's requested play time, needed position and voice-chat requirement.
/// The whole window must fit the organiser's availability; required voice chat must suit both players.
nonisolated struct SquadPlan: Equatable, Sendable {
  let playWindow: WeeklyPlayWindow
  let neededRole: PreferredRole
  let requiresVoiceChat: Bool

}

/// A compatible teammate together with the actual shared play interval.
/// Matching requires the same server, the needed position and at least 30 shared minutes.
/// The interval is the overlap, not necessarily the organiser's whole requested session.
nonisolated struct TeammateMatch: Identifiable, Equatable, Sendable {
  let teammate: GamingProfile
  let sharedWindow: WeeklyPlayWindow
  var id: PlayerIdentifier { teammate.id }
}

/// A snapshot of the organiser, requested conditions and ranked matches from one search.
/// Matches exclude saved avoidance preferences and rank by shared minutes, then name and identifier.
/// Changed organiser or teammate details require a new search before preparing a proposal.
nonisolated struct SquadSearch: Equatable, Sendable {
  let organiser: GamingProfile
  let plan: SquadPlan
  let matches: [TeammateMatch]
}

/// An unconfirmed suggestion for two players to arrange a game outside GameLink.
/// Preparation rechecks saved profiles and compatibility and includes only their actual shared time.
/// Sharing does not confirm delivery or acceptance; players must agree on an exact date in their chat.
nonisolated struct SquadProposal: Equatable, Sendable {
  let organiser: GamingProfile
  let teammate: GamingProfile
  let sharedWindow: WeeklyPlayWindow
  let requiresVoiceChat: Bool

  /// The message shared externally, excluding internal identifiers and private avoidance.
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
