import Foundation

@testable import GameLink

@MainActor
final class TestSquadNotebookRepository: SquadNotebookRepository {
  var notebook: SquadNotebook
  var failsToLoad = false
  var failsToSave = false
  private(set) var successfulSaveCount = 0

  init(notebook: SquadNotebook = SquadNotebook()) {
    self.notebook = notebook
  }

  func loadNotebook() throws -> SquadNotebook {
    if failsToLoad { throw TestNotebookFailure.unavailable }
    return notebook
  }

  func saveNotebook(_ notebook: SquadNotebook) throws {
    if failsToSave { throw TestNotebookFailure.unavailable }
    self.notebook = notebook
    successfulSaveCount += 1
  }
}

private enum TestNotebookFailure: Error {
  case unavailable
}

nonisolated enum SquadFixtures {
  static func window(
    day: PlayDay = .friday, start: Int = 1140, duration: Int = 120
  ) throws -> WeeklyPlayWindow {
    try WeeklyPlayWindow(day: day, startMinute: start, durationMinutes: duration)
  }

  static func draft(
    name: String = "Alex", server: GameServer = .oceania,
    role: PreferredRole = .bottom, day: PlayDay = .friday,
    start: Int = 1140, duration: Int = 120, voice: Bool = true
  ) throws -> GamingProfileDraft {
    GamingProfileDraft(
      gamerTag: name, server: server, preferredRole: role,
      availability: try window(day: day, start: start, duration: duration), usesVoiceChat: voice)
  }

  static func profile(
    id: PlayerIdentifier = PlayerIdentifier(), name: String = "Alex",
    server: GameServer = .oceania, role: PreferredRole = .bottom,
    day: PlayDay = .friday, start: Int = 1140, duration: Int = 120,
    voice: Bool = true
  ) throws -> GamingProfile {
    try GamingProfile(
      id: id,
      draft: draft(
        name: name, server: server, role: role, day: day,
        start: start, duration: duration, voice: voice))
  }

  static func contact(
    id: PlayerIdentifier = PlayerIdentifier(), name: String = "Miko",
    server: GameServer = .oceania, role: PreferredRole = .support,
    day: PlayDay = .friday, start: Int = 1140, duration: Int = 120,
    voice: Bool = true
  ) throws -> TeammateContact {
    TeammateContact(
      profile: try profile(
        id: id, name: name, server: server, role: role, day: day,
        start: start, duration: duration, voice: voice))
  }

  static func plan(
    day: PlayDay = .friday, start: Int = 1140, duration: Int = 120,
    role: PreferredRole = .support, voice: Bool = true
  ) throws -> SquadPlan {
    SquadPlan(
      playWindow: try window(day: day, start: start, duration: duration),
      neededRole: role, requiresVoiceChat: voice)
  }

  static func notebook() throws -> SquadNotebook {
    SquadNotebook(ownProfile: try profile(), contacts: [try contact()])
  }

  @MainActor
  static func saveLegacyExclusions(
    _ teammateIDs: Set<PlayerIdentifier>, in repository: any SquadNotebookRepository
  ) throws {
    var notebook = try repository.loadNotebook()
    notebook.avoidedPlayerIDs = teammateIDs
    try repository.saveNotebook(notebook)
  }
}
