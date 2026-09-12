import Testing

@testable import GameLink

@MainActor
struct TeammateDirectoryPresentationTests {
  private func directory(_ repository: any SquadNotebookRepository) -> TeammateDirectoryViewModel {
    TeammateDirectoryViewModel(saveContact: SaveTeammateContactUseCase(repository: repository))
  }

  @Test func addingRequiresAReadableSavedDirectory() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.beginAddingTeammate()
    #expect(model.editor == nil)
    model.reload()
    model.beginAddingTeammate()
    #expect(model.editor != nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unreadableContactsBlockEditingAndSupportRetry() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    let entry = try #require(model.entries.first)
    repository.failsToLoad = true
    model.reload()
    #expect(model.loadState == .unavailable(.notebookUnavailable))
    model.beginAddingTeammate()
    model.beginEditingTeammate(entry)
    #expect(model.editor == nil)
    repository.failsToLoad = false
    model.reload()
    #expect(model.loadState == .ready)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func savingTheInlineEditorClosesItAndRefreshesTheDirectory() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    model.beginAddingTeammate()
    let editor = try #require(model.editor)
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Jordan"))
    editor.permissionConfirmed = true
    model.saveEditor()
    #expect(model.editor == nil)
    #expect(model.entries.map { $0.contact.profile.gamerTag } == ["Miko", "Jordan"])
    #expect(model.saveConfirmation == "Teammate saved on this device.")
    #expect(repository.successfulSaveCount == 1)
  }

  @Test func aSecondContactCannotReplaceAnUnfinishedInlineDraft() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    model.beginAddingTeammate()
    let original = try #require(model.editor)
    original.form.gamerTag = "Unfinished teammate"
    model.beginAddingTeammate()
    model.beginEditingTeammate(try #require(model.entries.first))
    model.reload()
    #expect(model.editor === original)
    #expect(original.form.gamerTag == "Unfinished teammate")
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func cancellingAnEditedTeammateRequiresConfirmationAndNeverWrites() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    model.beginEditingTeammate(try #require(model.entries.first))
    let original = try #require(model.editor)
    original.form.gamerTag = "Changed draft"
    model.requestCancelEditing()
    #expect(model.showsDiscardConfirmation)
    #expect(model.editor === original)
    model.showsDiscardConfirmation = false
    #expect(model.editor === original)
    model.requestCancelEditing()
    model.discardEditor()
    #expect(model.editor == nil)
    #expect(!model.showsDiscardConfirmation)
    #expect(repository.notebook.contacts.first?.profile.gamerTag == "Miko")
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func cancellingAnUntouchedDraftDoesNotRequireConfirmation() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    model.beginAddingTeammate()
    model.requestCancelEditing()
    #expect(model.editor == nil)
    #expect(!model.showsDiscardConfirmation)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aFailedInlineSaveKeepsPermissionAndDraftForRetry() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = directory(repository)
    model.reload()
    model.beginAddingTeammate()
    let editor = try #require(model.editor)
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Jordan"))
    editor.permissionConfirmed = true
    repository.failsToSave = true
    model.saveEditor()
    #expect(model.editor === editor)
    #expect(editor.saveFailure == .contact(.contactNotSaved))
    #expect(editor.permissionConfirmed)
    #expect(model.saveConfirmation == nil)
    repository.failsToSave = false
    model.saveEditor()
    #expect(model.editor == nil)
    #expect(repository.successfulSaveCount == 1)
  }

  @Test func reopeningAndEditingALegacyExcludedContactPreservesItsIdentityAndExclusion() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let repository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    var notebook = try SquadFixtures.notebook()
    let contact = try #require(notebook.contacts.first)
    notebook.avoidedPlayerIDs = [contact.id]
    try repository.saveNotebook(notebook)
    let model = directory(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    model.reload()
    let entry = try #require(model.entries.first)
    #expect(entry.isAvoided)
    model.beginEditingTeammate(entry)
    let editor = try #require(model.editor)
    editor.form.gamerTag = "Miko Updated"
    editor.permissionConfirmed = true
    model.saveEditor()
    let reopened = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook()
    #expect(reopened.contacts.first?.id == contact.id)
    #expect(reopened.contacts.first?.profile.gamerTag == "Miko Updated")
    #expect(reopened.avoidedPlayerIDs == [contact.id])
    #expect(
      try FindCompatibleTeammatesUseCase(repository: repository).execute(SquadFixtures.plan())
        .matches.isEmpty)
  }

  @Test func managingTeammatesRequiresTheOrganisersProfileEditsToBeSaved() throws {
    let repository = TestSquadNotebookRepository()
    let profile = GamingProfileViewModel(
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
