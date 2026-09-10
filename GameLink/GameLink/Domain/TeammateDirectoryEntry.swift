nonisolated struct TeammateDirectoryEntry: Identifiable, Equatable, Sendable {
  let contact: TeammateContact
  let isAvoided: Bool

  var id: PlayerIdentifier { contact.id }
}
