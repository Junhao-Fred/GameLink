/// Checks whether a saved teammate fits the plan and returns their shared time.
/// Excludes the organiser; requires the same server, requested position and at least 30 shared minutes.
/// Voice support is needed only when requested. Use Cases check organiser availability and exclusions.
nonisolated protocol TeammateMatchingRule: Sendable {
  /// Returns a match and its shared time, or nil if a condition fails.
  func match(
    for contact: TeammateContact, organiser: GamingProfile, plan: SquadPlan
  ) -> TeammateMatch?
}

/// Applies matching rules to self-reported profiles in the saved circle.
nonisolated struct SavedTeammateMatchingRule: TeammateMatchingRule {
  /// Checks identity, server, position, voice support and shared time.
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
