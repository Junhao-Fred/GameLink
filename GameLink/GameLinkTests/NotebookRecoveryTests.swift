import Foundation
import Testing

@testable import GameLink

@Suite("Actionable recovery when saved squad details cannot be used")
@MainActor
struct NotebookRecoveryTests {
  @Test(arguments: RecoveryScenario.allCases, NotebookOperation.allCases)
  func eachOperationExplainsRequiredRecovery(
    scenario: RecoveryScenario, operation: NotebookOperation
  ) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try repository.saveNotebook(SquadFixtures.notebook())
    let search = try FindCompatibleTeammatesUseCase(repository: repository).execute(
      SquadFixtures.plan())
    let teammateID = try #require(search.matches.first?.id)
    let draft = try SquadFixtures.draft(name: "NewPlayer")
    try scenario.damage(sandbox.fileURL)
    let bytesBefore = try? Data(contentsOf: sandbox.fileURL)

    do {
      switch operation {
      case .loadProfile:
        _ = try SaveGamingProfileUseCase(repository: repository).loadSavedProfile()
      case .saveProfile:
        _ = try SaveGamingProfileUseCase(repository: repository).execute(draft)
      case .loadTeammates:
        _ = try SaveTeammateContactUseCase(repository: repository).loadSavedTeammates()
      case .saveTeammate:
        _ = try SaveTeammateContactUseCase(repository: repository).execute(
          draft, permissionConfirmed: true)
      case .loadOrganiser:
        _ = try FindCompatibleTeammatesUseCase(repository: repository).loadOrganiser()
      case .findTeammates:
        _ = try FindCompatibleTeammatesUseCase(repository: repository).execute(search.plan)
      case .prepareProposal:
        _ = try PrepareSquadProposalUseCase(repository: repository).execute(
          teammateID: teammateID, from: search)
      }
      Issue.record("Unavailable saved details must stop this operation.")
    } catch {
      #expect(error.localizedDescription.contains(scenario.requiredGuidance))
      #expect(!error.localizedDescription.contains("Unlock your device"))
    }
    #expect((try? Data(contentsOf: sandbox.fileURL)) == bytesBefore)
  }

  @Test(arguments: RecoveryScenario.allCases)
  func profileShowsRecoveryAndProtectsTheOriginalFile(scenario: RecoveryScenario) throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    try repository.saveNotebook(SquadFixtures.notebook())
    try scenario.damage(sandbox.fileURL)
    let model = GamingProfileViewModel(
      saveProfile: SaveGamingProfileUseCase(repository: repository))
    model.loadIfNeeded()
    guard case .unavailable(let failure) = model.loadState else {
      Issue.record("Profile must explain why saved data cannot be opened.")
      return
    }
    #expect(failure.localizedDescription.contains(scenario.requiredGuidance))
    #expect(!model.canSave)
    let bytesBefore = try? Data(contentsOf: sandbox.fileURL)
    model.save()
    #expect((try? Data(contentsOf: sandbox.fileURL)) == bytesBefore)
  }

  @Test(arguments: [
    (SquadNotebookAccessError.unsupportedStorageVersion, "Use a compatible app version"),
    (.savedDetailsInvalid, "restore a valid device backup"),
    (.savedDetailsMissing, "Restore the saved file"),
    (.changesNotSaved, "check available device storage"),
  ])
  func failureDuringSaveKeepsBothDraftsAndSpecificRecovery(
    failure: SquadNotebookAccessError, requiredGuidance: String
  ) throws {
    let original = try SquadFixtures.notebook()
    let repository = SaveFailingNotebookRepository(notebook: original, failure: failure)
    let profile = GamingProfileViewModel(
      saveProfile: SaveGamingProfileUseCase(repository: repository))
    profile.loadIfNeeded()
    profile.form.gamerTag = "UpdatedAlex"
    profile.save()
    #expect(profile.saveFailure?.localizedDescription.contains(requiredGuidance) == true)
    #expect(profile.form.gamerTag == "UpdatedAlex")
    #expect(!profile.showsSaveConfirmation)
    #expect(profile.savedProfile == original.ownProfile)

    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository))
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "NewPlayer"))
    editor.permissionConfirmed = true
    #expect(!editor.save())
    #expect(editor.saveFailure?.localizedDescription.contains(requiredGuidance) == true)
    #expect(editor.form.gamerTag == "NewPlayer")
    #expect(editor.savedContact == nil)
    #expect(repository.notebook == original)
  }

}

nonisolated enum NotebookOperation: CaseIterable {
  case loadProfile, saveProfile, loadTeammates, saveTeammate
  case loadOrganiser, findTeammates, prepareProposal
}

nonisolated enum RecoveryScenario: CaseIterable {
  case incompatibleVersion, invalidDetails, missingKnownFile

  var requiredGuidance: String {
    switch self {
    case .incompatibleVersion: "Use a compatible app version"
    case .invalidDetails: "restore a valid device backup"
    case .missingKnownFile: "Restore the saved file"
    }
  }

  func damage(_ fileURL: URL) throws {
    switch self {
    case .incompatibleVersion:
      try Data(#"{"schemaVersion":999}"#.utf8).write(to: fileURL)
    case .invalidDetails:
      try Data("damaged saved details".utf8).write(to: fileURL)
    case .missingKnownFile:
      try FileManager.default.removeItem(at: fileURL)
    }
  }
}

/// Simulates a storage failure after reading but before saving.
@MainActor
private final class SaveFailingNotebookRepository: SquadNotebookRepository {
  let notebook: SquadNotebook
  let failure: SquadNotebookAccessError

  init(notebook: SquadNotebook, failure: SquadNotebookAccessError) {
    self.notebook = notebook
    self.failure = failure
  }

  func loadNotebook() throws -> SquadNotebook { notebook }
  func saveNotebook(_ notebook: SquadNotebook) throws { throw failure }
}
