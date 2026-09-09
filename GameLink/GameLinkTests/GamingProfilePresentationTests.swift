import Foundation
import Testing

@testable import GameLink

@MainActor
struct LoadGamingProfileTests {
  @Test func firstLaunchHasNoSavedPlayerProfile() throws {
    let repository = TestSquadNotebookRepository()
    #expect(try LoadGamingProfileUseCase(repository: repository).execute() == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func savedPlayerProfileIsReturnedWithoutChangingSquadDetails() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    #expect(try LoadGamingProfileUseCase(repository: repository).execute() == notebook.ownProfile)
    #expect(repository.notebook == notebook)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func unreadableNotebookIsNotTreatedAsAnEmptyProfile() {
    let repository = TestSquadNotebookRepository()
    repository.failsToLoad = true
    #expect(throws: LoadGamingProfileError.profileUnavailable) {
      try LoadGamingProfileUseCase(repository: repository).execute()
    }
    #expect(repository.successfulSaveCount == 0)
  }
}

struct GamingProfileFormTests {
  @Test func firstProfileRequiresExplicitServerPositionAndWeekday() throws {
    var form = GamingProfileForm()
    #expect(throws: GamingProfileFormError.chooseServer) { try form.makeDraft() }
    form.server = .oceania
    #expect(throws: GamingProfileFormError.chooseRole) { try form.makeDraft() }
    form.preferredRole = .support
    #expect(throws: GamingProfileFormError.choosePlayDay) { try form.makeDraft() }
    form.playDay = .friday
    #expect(try form.makeDraft().availability.day == .friday)
  }

  @Test(arguments: [0, 1, 59, 60, 1147, 1380, 1439])
  func clockSelectionPreservesEveryStoredMinute(_ minute: Int) {
    var form = GamingProfileForm()
    form.startMinute = minute
    let selectedTime = form.startTime
    #expect(GamingProfileForm.clockCalendar.component(.hour, from: selectedTime) == minute / 60)
    #expect(GamingProfileForm.clockCalendar.component(.minute, from: selectedTime) == minute % 60)
    form.startMinute = 0
    form.startTime = selectedTime
    #expect(form.startMinute == minute)
    #expect(GamingProfileForm.clockCalendar.timeZone.secondsFromGMT(for: selectedTime) == 0)
  }

  @Test func savedNonQuarterHourAvailabilityIsNotRoundedWhenEditing() throws {
    let profile = try SquadFixtures.profile(start: 1147, duration: 37)
    let form = GamingProfileForm(profile: profile)
    #expect(try form.makeDraft().availability == profile.availability)
    #expect(form.availabilitySummary == profile.availability.summary)
  }

  @Test func playWindowMayEndAtMidnightButCannotCrossIntoTheNextDay() throws {
    var form = GamingProfileForm(profile: try SquadFixtures.profile(start: 1380, duration: 60))
    #expect(try form.makeDraft().availability.endMinute == 1440)
    form.durationMinutes = 75
    #expect(throws: GamingProfileFormError.invalidPlayWindow(.crossesMidnight)) {
      try form.makeDraft()
    }
    #expect(form.availabilitySummary == nil)
  }
}

@MainActor
struct GamingProfileViewModelTests {
  private func viewModel(_ repository: any SquadNotebookRepository) -> GamingProfileViewModel {
    GamingProfileViewModel(
      loadProfile: LoadGamingProfileUseCase(repository: repository),
      saveProfile: SaveGamingProfileUseCase(repository: repository))
  }

  @Test func savingIsBlockedUntilExistingProfileHasBeenChecked() {
    let repository = TestSquadNotebookRepository()
    let model = viewModel(repository)
    #expect(!model.canSave)
    model.save()
    #expect(repository.successfulSaveCount == 0)
    model.loadIfNeeded()
    #expect(model.loadState == .ready)
    #expect(model.canSave)
    #expect(model.savedProfile == nil)
  }

  @Test func openingSavedProfileRestoresEveryEditableField() throws {
    let profile = try SquadFixtures.profile(
      server: .europeWest, role: .jungle, day: .sunday, start: 1147, duration: 37, voice: false)
    let model = viewModel(TestSquadNotebookRepository(notebook: SquadNotebook(ownProfile: profile)))
    model.loadIfNeeded()
    #expect(model.form == GamingProfileForm(profile: profile))
    #expect(model.savedProfile == profile)
    #expect(!model.hasUnsavedChanges)
    #expect(!model.canSave)
    #expect(!model.showsSaveConfirmation)
  }

  @Test func unavailableProfileBlocksEditsFromBeingSavedAndCanBeRetried() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    repository.failsToLoad = true
    let model = viewModel(repository)
    model.loadIfNeeded()
    #expect(model.loadState == .unavailable(.profileUnavailable))
    #expect(!model.canSave)
    model.save()
    #expect(repository.successfulSaveCount == 0)
    repository.failsToLoad = false
    model.loadIfNeeded()
    #expect(model.loadState == .ready)
    #expect(model.savedProfile == notebook.ownProfile)
  }

  @Test func savingFirstProfileTrimsNameAndConfirmsOnlyOneSuccessfulWrite() throws {
    let repository = TestSquadNotebookRepository()
    let model = viewModel(repository)
    model.loadIfNeeded()
    model.form = GamingProfileForm(profile: try SquadFixtures.profile(name: "Alex"))
    model.form.gamerTag = "  Alex  "
    model.save()
    #expect(model.form.gamerTag == "Alex")
    #expect(model.savedProfile == repository.notebook.ownProfile)
    #expect(model.showsSaveConfirmation)
    #expect(!model.canSave)
    model.save()
    #expect(repository.successfulSaveCount == 1)
    model.form.gamerTag = "Alexandra"
    #expect(!model.showsSaveConfirmation)
    #expect(model.hasUnsavedChanges)
  }

  @Test func profileSaveFailureKeepsDraftAndPreviouslySavedSquadDetails() throws {
    let notebook = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let model = viewModel(repository)
    model.loadIfNeeded()
    model.form.gamerTag = "Alexandra"
    repository.failsToSave = true
    model.save()
    #expect(model.form.gamerTag == "Alexandra")
    #expect(model.savedProfile == notebook.ownProfile)
    #expect(repository.notebook == notebook)
    #expect(model.saveFailure == .profile(.profileNotSaved))
    #expect(model.showsSaveFailure)
    #expect(!model.showsSaveConfirmation)
    repository.failsToSave = false
    model.save()
    #expect(model.savedProfile?.gamerTag == "Alexandra")
    #expect(model.saveFailure == nil)
    #expect(model.showsSaveConfirmation)
  }

  @Test(arguments: ["", String(repeating: "A", count: 41), "Alex\nPlayer"])
  func invalidPlayerNameRemainsEditableAndIsNeverSaved(_ name: String) throws {
    let repository = TestSquadNotebookRepository()
    let model = viewModel(repository)
    model.loadIfNeeded()
    model.form = GamingProfileForm(profile: try SquadFixtures.profile())
    model.form.gamerTag = name
    model.save()
    #expect(model.saveFailure?.field == .playerName)
    #expect(model.form.gamerTag == name)
    #expect(model.savedProfile == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func teammateIdentityCannotBeUsedAsThePlayersOwnProfile() throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let model = viewModel(repository)
    model.loadIfNeeded()
    model.form.gamerTag = "Miko"
    model.save()
    #expect(model.saveFailure == .profile(.nameUsedByTeammate))
    #expect(model.form.gamerTag == "Miko")
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func missingServerIsReportedBesideItsSelectionWithoutWriting() {
    let repository = TestSquadNotebookRepository()
    let model = viewModel(repository)
    model.loadIfNeeded()
    model.save()
    #expect(model.saveFailure == .form(.chooseServer))
    #expect(model.saveFailure?.message(for: .server) != nil)
    #expect(model.saveFailure?.message(for: .role) == nil)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test func returningToProfileDoesNotReplaceUnsavedEdits() throws {
    let model = viewModel(TestSquadNotebookRepository(notebook: try SquadFixtures.notebook()))
    model.loadIfNeeded()
    model.form.gamerTag = "Alexandra"
    model.loadIfNeeded()
    #expect(model.form.gamerTag == "Alexandra")
    #expect(model.savedProfile?.gamerTag == "Alex")
  }

  @Test func choosingServerClearsItsOldErrorButUnrelatedEditsDoNot() {
    let model = viewModel(TestSquadNotebookRepository())
    model.loadIfNeeded()
    model.save()
    model.showsSaveFailure = false
    model.form.gamerTag = "Alex"
    #expect(model.saveFailure == .form(.chooseServer))
    model.form.server = .oceania
    #expect(model.saveFailure == nil)
    #expect(!model.showsSaveFailure)
  }

  @Test func editingProfilePreservesPlayerIdentifierContactsAndPrivateExclusions() throws {
    var notebook = try SquadFixtures.notebook()
    notebook.avoidedPlayerIDs = [try #require(notebook.contacts.first).id]
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let model = viewModel(repository)
    model.loadIfNeeded()
    model.form.gamerTag = "Alexandra"
    model.save()
    #expect(model.savedProfile?.id == notebook.ownProfile?.id)
    #expect(repository.notebook.contacts == notebook.contacts)
    #expect(repository.notebook.avoidedPlayerIDs == notebook.avoidedPlayerIDs)
  }

  @Test func reopeningProfileFromDiskRestoresSavedEditsAndStablePlayerIdentifier() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let original = viewModel(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    original.loadIfNeeded()
    original.form = GamingProfileForm(profile: try SquadFixtures.profile(start: 1147, duration: 37))
    original.save()
    let storedProfile = try #require(original.savedProfile)
    let reopened = viewModel(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    reopened.loadIfNeeded()
    #expect(reopened.savedProfile == storedProfile)
    #expect(reopened.form == GamingProfileForm(profile: storedProfile))
    reopened.form.gamerTag = "Alexandra"
    reopened.save()
    #expect(reopened.savedProfile?.id == storedProfile.id)
    let finalRepository = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    #expect(try finalRepository.loadNotebook().ownProfile == reopened.savedProfile)
  }

  @Test func damagedSavedProfileIsNotReplacedByFirstLaunchForm() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let originalBytes = Data("not a valid squad notebook".utf8)
    try originalBytes.write(to: sandbox.fileURL)
    let model = viewModel(try LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    model.loadIfNeeded()
    #expect(model.loadState == .unavailable(.profileUnavailable))
    model.save()
    #expect(try Data(contentsOf: sandbox.fileURL) == originalBytes)
  }
}
