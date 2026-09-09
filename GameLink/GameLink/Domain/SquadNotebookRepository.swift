nonisolated struct SquadNotebook: Equatable, Sendable {
  var ownProfile: GamingProfile?
  var contacts: [TeammateContact] = []
  var avoidedPlayerIDs: Set<PlayerIdentifier> = []
}

@MainActor
protocol SquadNotebookRepository {
  func loadNotebook() throws -> SquadNotebook
  func saveNotebook(_ notebook: SquadNotebook) throws
}
