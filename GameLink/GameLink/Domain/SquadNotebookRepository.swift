/// The organiser's local profile, teammate directory and private search exclusions.
/// Contacts require an organiser and unique identities; exclusions must refer to saved contacts.
/// Existing exclusions remain stored and applied even though this version cannot edit them.
nonisolated struct SquadNotebook: Equatable, Sendable {
  var ownProfile: GamingProfile?
  var contacts: [TeammateContact] = []
  var avoidedPlayerIDs: Set<PlayerIdentifier> = []
}

/// The storage contract used by business operations without depending on JSON or file paths.
/// Implementations report known access failures as `SquadNotebookAccessError` to retain recovery guidance.
@MainActor
protocol SquadNotebookRepository {
  /// Returns the current notebook, reporting unavailable data instead of inventing contacts.
  func loadNotebook() throws -> SquadNotebook
  /// Replaces the notebook; a failed save must preserve the previously stored details.
  func saveNotebook(_ notebook: SquadNotebook) throws
}
