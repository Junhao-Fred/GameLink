/// Decides whether a saved teammate fits the requested session and returns their shared time.
/// Matching excludes the organiser, requires the same server and requested position, honours
/// required voice chat and requires at least 30 shared minutes. Use Cases additionally check
/// the organiser's availability and private exclusions before accepting a match.
nonisolated protocol TeammateMatchingRule: Sendable {
  /// Returns the eligible teammate and actual overlap, or nil when a condition is not met.
  func match(
    for contact: TeammateContact, organiser: GamingProfile, plan: SquadPlan
  ) -> TeammateMatch?
}

/// Applies GameLink's matching conditions to self-reported profiles in a saved gaming circle.
nonisolated struct SavedTeammateMatchingRule: TeammateMatchingRule {
  /// Checks a teammate's identity, server, role, voice preference and shared time.
  /// The search Use Case separately checks own availability and private avoidance.
  func match(
    for contact: TeammateContact, organiser: GamingProfile, plan: SquadPlan
  ) -> TeammateMatch? {
    let teammate = contact.profile
    guard teammate.id != organiser.id,
      !teammate.hasSameLocalIdentity(as: organiser),
      teammate.server == organiser.server,
      teammate.preferredRole == plan.neededRole,
      !plan.requiresVoiceChat || teammate.usesVoiceChat,
      let sharedWindow = plan.playWindow.sharedWindow(with: teammate.availability)
    else { return nil }
    return TeammateMatch(teammate: teammate, sharedWindow: sharedWindow)
  }
}
