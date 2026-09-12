/// A saved teammate and their exclusion status.
/// Excluded teammates remain visible in the directory but do not appear in matches.
nonisolated struct TeammateDirectoryEntry: Identifiable, Equatable, Sendable {
  let contact: TeammateContact
  let isAvoided: Bool

  var id: PlayerIdentifier { contact.id }
}
