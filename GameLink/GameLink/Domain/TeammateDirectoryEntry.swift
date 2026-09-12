/// A saved teammate paired with the organiser's private avoidance preference.
/// An excluded teammate stays visible in the directory but cannot appear in matching results.
nonisolated struct TeammateDirectoryEntry: Identifiable, Equatable, Sendable {
  let contact: TeammateContact
  let isAvoided: Bool

  var id: PlayerIdentifier { contact.id }
}
