import Foundation

@MainActor
struct LoadGamingProfileUseCase {
  let repository: any SquadNotebookRepository

  func execute() throws(LoadGamingProfileError) -> GamingProfile? {
    do { return try repository.loadNotebook().ownProfile } catch { throw .profileUnavailable }
  }
}

nonisolated enum LoadGamingProfileError: LocalizedError, Equatable, Sendable {
  case profileUnavailable

  var errorDescription: String? {
    "Your saved profile could not be opened. Unlock your device and try again. If this continues, keep your saved data and use a compatible app version or restore a known-good backup. Do not reinstall GameLink."
  }
}
