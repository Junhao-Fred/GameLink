import Testing

@testable import GameLink

@MainActor
struct TeammateContactEditorTests {
  @Test(arguments: [false, true])
  func savingNewOrEditedDetailsRequiresFreshPermission(isEditing: Bool) throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository),
      contact: isEditing ? notebook.contacts.first : nil)
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Jordan"))

    #expect(!editor.permissionConfirmed)
    #expect(!editor.save())
    #expect(editor.saveFailure == .contact(.permissionRequired))
    #expect(editor.savedContact == nil)
    #expect(repository.notebook == notebook)
    #expect(repository.successfulSaveCount == 0)

    editor.permissionConfirmed = true
    #expect(editor.saveFailure == nil)
    #expect(editor.save())
    #expect(repository.successfulSaveCount == 1)
  }

  @Test func savingATeammateTrimsTheirNameAndCannotSubmitTheSameDraftTwice() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository))
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Jordan"))
    editor.form.gamerTag = "  Jordan  "
    editor.permissionConfirmed = true

    #expect(editor.save())
    #expect(editor.savedContact?.profile.gamerTag == "Jordan")
    #expect(!editor.hasUnsavedChanges)
    #expect(!editor.save())
    #expect(repository.successfulSaveCount == 1)
    #expect(repository.notebook.contacts.count == 2)
  }

  @Test func dismissingAnUnsavedDraftDoesNotCreateOrChangeAnyContact() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository))
    #expect(!editor.hasUnsavedChanges)
    editor.form.gamerTag = "Jordan"
    #expect(editor.hasUnsavedChanges)
    #expect(repository.notebook == notebook)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func editingAnAvoidedTeammatePreservesTheirIdentityAndExclusion() throws {
    var notebook = try SquadFixtures.notebook()
    let teammate = try #require(notebook.contacts.first)
    notebook.avoidedPlayerIDs = [teammate.id]
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository), contact: teammate)
    #expect(editor.form == GamingProfileForm(profile: teammate.profile))
    editor.form.gamerTag = "Miko Updated"
    editor.permissionConfirmed = true

    #expect(editor.save())
    #expect(editor.savedContact?.id == teammate.id)
    #expect(repository.notebook.contacts.count == 1)
    #expect(repository.notebook.avoidedPlayerIDs == [teammate.id])
    #expect(repository.notebook.ownProfile == notebook.ownProfile)
  }

  @Test func failedSaveKeepsTheDraftAndOriginalContactUntilRetrySucceeds() throws {
    let notebook = try SquadFixtures.notebook()
    let teammate = try #require(notebook.contacts.first)
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository), contact: teammate)
    editor.form.gamerTag = "Miko Updated"
    editor.permissionConfirmed = true
    repository.failsToSave = true

    #expect(!editor.save())
    #expect(editor.form.gamerTag == "Miko Updated")
    #expect(editor.hasUnsavedChanges)
    #expect(editor.savedContact == nil)
    #expect(editor.saveFailure == .contact(.contactNotSaved))
    #expect(repository.notebook == notebook)

    repository.failsToSave = false
    #expect(editor.save())
    #expect(editor.savedContact?.id == teammate.id)
    #expect(editor.saveFailure == nil)
    #expect(!editor.showsSaveFailure)
  }

  @Test func anExistingNameAndServerCannotCreateADuplicateContact() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository))
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "miko"))
    editor.permissionConfirmed = true
    #expect(!editor.save())
    #expect(editor.saveFailure == .contact(.duplicateTeammate))
    #expect(editor.saveFailure?.field == .playerName)
    #expect(repository.successfulSaveCount == 0)
    editor.form.preferredRole = .jungle
    #expect(editor.saveFailure == .contact(.duplicateTeammate))
    editor.form.gamerTag = "Jordan"
    #expect(editor.saveFailure == nil)
  }

  @Test func aMissingSelectionIsShownBesideTheAffectedField() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository))
    editor.permissionConfirmed = true
    #expect(!editor.save())
    #expect(editor.saveFailure == .form(.chooseServer))
    #expect(editor.saveFailure?.field == .server)
    editor.form.gamerTag = "Jordan"
    #expect(editor.saveFailure == .form(.chooseServer))
    editor.form.server = .oceania
    #expect(editor.saveFailure == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func aPlayWindowCrossingMidnightIsKeptForCorrectionAndNeverSaved() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository))
    editor.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Jordan"))
    editor.form.startMinute = 1380
    editor.form.durationMinutes = 120
    editor.permissionConfirmed = true
    #expect(!editor.save())
    #expect(editor.saveFailure == .form(.invalidPlayWindow(.crossesMidnight)))
    #expect(editor.form.startMinute == 1380)
    #expect(repository.successfulSaveCount == 0)
    editor.form.durationMinutes = 60
    #expect(editor.save())
    #expect(editor.savedContact?.profile.availability.endMinute == 1440)
  }

  @Test func aContactRemovedWhileEditingIsNotRecreatedFromTheOldDraft() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let contact = try #require(notebook.contacts.first)
    let editor = TeammateContactEditorViewModel(
      saveContact: SaveTeammateContactUseCase(repository: repository),
      contact: contact)
    editor.form.gamerTag = "Miko Updated"
    editor.permissionConfirmed = true
    repository.notebook.contacts = []
    #expect(!editor.save())
    #expect(editor.saveFailure == .contact(.contactNoLongerExists))
    #expect(editor.hasUnsavedChanges)
    #expect(repository.notebook.contacts.isEmpty)
    #expect(repository.successfulSaveCount == 0)
  }
}
