import Testing

@testable import GameLink

@MainActor
struct TeammateDirectoryPresentationTests {
  private func directory(_ repository: any SquadNotebookRepository) -> TeammateDirectoryViewModel {
    TeammateDirectoryViewModel(
      loadDirectory: LoadTeammateDirectoryUseCase(repository: repository),
      saveContact: SaveTeammateContactUseCase(repository: repository),
      setAvoidance: SetTeammateAvoidanceUseCase(repository: repository))
  }

  @Test func addingTeammatesIsBlockedBeforeTheSavedDirectoryHasBeenChecked() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.beginAddingTeammate()
    #expect(model.editor == nil)
    model.reload()
    model.beginAddingTeammate()
    #expect(model.editor?.contactID == nil)
    #expect(model.editor != nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func anUnavailableDirectoryBlocksChangesAndCanBeRetried() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let model = directory(repository)
    model.reload()
    let entry = try #require(model.entries.first)
    repository.failsToLoad = true
    model.reload()
    #expect(model.loadState == .unavailable(.directoryUnavailable))
    model.beginAddingTeammate()
    model.beginEditingTeammate(entry)
    model.changeAvoidance(for: entry)
    #expect(model.editor == nil)
    #expect(repository.successfulSaveCount == 0)
    repository.failsToLoad = false
    model.reload()
    #expect(model.loadState == .ready)
    #expect(model.entries.map(\.contact) == notebook.contacts)
  }

  @Test func savingAnEditorThenReloadingShowsTheNewTeammate() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    model.beginAddingTeammate()
    let editor = try #require(model.editor)
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Jordan"))
    editor.permissionConfirmed = true
    #expect(editor.save())
    model.editor = nil
    model.reload()
    #expect(model.entries.map { $0.contact.profile.gamerTag } == ["Miko", "Jordan"])
  }

  @Test func avoidingAndRestoringATeammateChangesSearchEligibilityWithoutRemovingTheirRow() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    let entry = try #require(model.entries.first)
    model.changeAvoidance(for: entry)
    #expect(model.entries.count == 1)
    #expect(model.entries.first?.isAvoided == true)
    #expect(
      try FindCompatibleTeammatesUseCase(repository: repository).execute(SquadFixtures.plan())
        .matches.isEmpty)
    let avoidedEntry = try #require(model.entries.first)
    model.changeAvoidance(for: avoidedEntry)
    #expect(model.entries.first?.isAvoided == false)
    #expect(
      try FindCompatibleTeammatesUseCase(repository: repository).execute(SquadFixtures.plan())
        .matches.map(\.id) == [entry.id])
  }

  @Test func failedAvoidanceKeepsTheVisiblePreferenceAndSupportsRetry() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let model = directory(repository)
    model.reload()
    let entry = try #require(model.entries.first)
    repository.failsToSave = true
    model.changeAvoidance(for: entry)
    #expect(model.entries.first?.isAvoided == false)
    #expect(model.avoidanceFailure == .preferenceNotSaved)
    #expect(model.showsAvoidanceFailure)
    #expect(model.preferenceConfirmation == nil)
    #expect(repository.notebook == notebook)
    repository.failsToSave = false
    model.changeAvoidance(for: entry)
    #expect(model.entries.first?.isAvoided == true)
    #expect(model.avoidanceFailure == nil)
    #expect(!model.showsAvoidanceFailure)
  }

  @Test func reopenedDirectoryPreservesEditedTeammatesAndAvoidanceOnDisk() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    _ = try SaveGamingProfileUseCase(repository: repository).execute(SquadFixtures.draft())
    let model = directory(repository)
    model.reload()
    model.beginAddingTeammate()
    let editor = try #require(model.editor)
    editor.form = GamingProfileForm(
      profile: try SquadFixtures.profile(name: "Jordan", start: 1147, duration: 37))
    editor.permissionConfirmed = true
    #expect(editor.save())
    model.editor = nil
    model.reload()
    model.changeAvoidance(for: try #require(model.entries.first))

    let reopened = directory(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    reopened.reload()
    let savedEntry = try #require(reopened.entries.first)
    #expect(savedEntry.isAvoided)
    #expect(savedEntry.contact.profile.availability.startMinute == 1147)
    reopened.beginEditingTeammate(savedEntry)
    let editing = try #require(reopened.editor)
    editing.form.gamerTag = "Jordan Updated"
    editing.permissionConfirmed = true
    #expect(editing.save())

    let finalRepository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    let finalEntry = try #require(
      LoadTeammateDirectoryUseCase(repository: finalRepository).execute().first)
    #expect(finalEntry.id == savedEntry.id)
    #expect(finalEntry.contact.profile.gamerTag == "Jordan Updated")
    #expect(finalEntry.contact.profile.availability.durationMinutes == 37)
    #expect(finalEntry.isAvoided)
  }

  @Test func managingTeammatesRequiresTheOrganisersProfileEditsToBeSaved() throws {
    let repository = TestSquadNotebookRepository()
    let profile = GamingProfileViewModel(
      loadProfile: LoadGamingProfileUseCase(repository: repository),
      saveProfile: SaveGamingProfileUseCase(repository: repository))
    profile.loadIfNeeded()
    #expect(!profile.canManageTeammates)
    profile.form = GamingProfileForm(profile: try SquadFixtures.profile())
    profile.save()
    #expect(profile.canManageTeammates)
    profile.form.gamerTag = "Alex Updated"
    #expect(!profile.canManageTeammates)
    repository.failsToSave = true
    profile.save()
    #expect(!profile.canManageTeammates)
    repository.failsToSave = false
    profile.save()
    #expect(profile.canManageTeammates)
  }
}
