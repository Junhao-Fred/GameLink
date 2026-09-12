/// The organiser's profile, saved teammates and private exclusions.
/// Teammates need an organiser and unique identities; exclusions must refer to saved teammates.
/// Existing exclusions still apply even though this version cannot edit them.
nonisolated struct SquadNotebook: Equatable, Sendable {
  var ownProfile: GamingProfile?
  var contacts: [TeammateContact] = []
  var avoidedPlayerIDs: Set<PlayerIdentifier> = []
}

/// Loads and saves squad details without exposing JSON or file paths.
/// Known failures use `SquadNotebookAccessError` so recovery guidance reaches the player.
@MainActor
protocol SquadNotebookRepository {
  /// Loads saved details or reports a failure; never invents contacts.
  func loadNotebook() throws -> SquadNotebook
  /// Saves the notebook; failure must leave previous details unchanged.
  func saveNotebook(_ notebook: SquadNotebook) throws
}
