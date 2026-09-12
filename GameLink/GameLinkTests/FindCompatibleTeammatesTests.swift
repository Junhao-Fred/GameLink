import Testing

@testable import GameLink

@Suite("Finding compatible teammates")
@MainActor
struct FindCompatibleTeammatesTests {
  @Test func findsASameServerTeammateWithTheRequestedRoleAndSharedTime() throws {
    let original = try SquadFixtures.notebook()
    let repository = TestSquadNotebookRepository(notebook: original)
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    let match = try #require(search.matches.first)
    #expect(search.matches.count == 1)
    #expect(match.teammate.gamerTag == "Miko")
    #expect(match.sharedWindow.startMinute == 1140)
    #expect(match.sharedWindow.durationMinutes == 120)
    #expect(repository.notebook == original)
    #expect(repository.successfulSaveCount == 0)
  }

  @Test(arguments: [(1230, 1), (1231, 0)])
  func thirtySharedMinutesQualifyButTwentyNineDoNot(start: Int, expectedMatches: Int) throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(),
        contacts: [try SquadFixtures.contact(start: start, duration: 60)]))
    let search = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(search.matches.count == expectedMatches)
  }

  @Test(arguments: [GameServer.europeWest, .northAmerica])
  func excludesTeammatesOnAnotherServer(_ server: GameServer) throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(),
        contacts: [try SquadFixtures.contact(server: server)]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test(arguments: [PreferredRole.top, .jungle, .middle, .bottom])
  func excludesPlayersWhoDoNotFillTheRequestedRole(_ role: PreferredRole) throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(),
        contacts: [try SquadFixtures.contact(role: role)]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test func excludesTeammatesWhoPlayOnAnotherDay() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(),
        contacts: [try SquadFixtures.contact(day: .saturday)]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test func excludesTeammatesWithoutRequiredVoiceChat() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(),
        contacts: [try SquadFixtures.contact(voice: false)]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test func optionalVoiceChatAllowsPlayersWithoutVoiceChat() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(voice: false),
        contacts: [try SquadFixtures.contact(voice: false)]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan(voice: false))
    #expect(result.matches.count == 1)
  }

  @Test func doesNotRecommendTheOrganiserEvenIfTheyAppearInTheDirectory() throws {
    let organiser = try SquadFixtures.profile(role: .support)
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: organiser, contacts: [TeammateContact(profile: organiser)]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test func excludesAPrivatelyAvoidedTeammate() throws {
    var notebook = try SquadFixtures.notebook()
    let teammate = try #require(notebook.contacts.first)
    notebook.avoidedPlayerIDs.insert(teammate.id)
    let repository = TestSquadNotebookRepository(notebook: notebook)
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test func ranksLongerSharedTimeFirstAndBreaksTiesByPlayerName() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(
        ownProfile: try SquadFixtures.profile(),
        contacts: [
          try SquadFixtures.contact(name: "Zed"),
          try SquadFixtures.contact(name: "Amy", start: 1170, duration: 90),
          try SquadFixtures.contact(name: "Bob"),
        ]))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.map(\.teammate.gamerTag) == ["Bob", "Zed", "Amy"])
    #expect(result.matches.map(\.sharedWindow.durationMinutes) == [120, 120, 90])
  }

  @Test func anEmptyDirectoryProducesAnEmptyResultNotAnError() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile()))
    let result = try FindCompatibleTeammatesUseCase(repository: repository)
      .execute(SquadFixtures.plan())
    #expect(result.matches.isEmpty)
  }

  @Test func requiresASavedProfileBeforeSearching() throws {
    let repository = TestSquadNotebookRepository()
    let plan = try SquadFixtures.plan()
    #expect(throws: FindCompatibleTeammatesError.ownProfileRequired) {
      try FindCompatibleTeammatesUseCase(repository: repository).execute(plan)
    }
  }

  @Test(arguments: [(1139, 120), (1141, 120)])
  func rejectsPlansThatExtendOutsideTheOrganisersAvailability(start: Int, duration: Int) throws {
    let repository = TestSquadNotebookRepository(notebook: try SquadFixtures.notebook())
    let plan = try SquadFixtures.plan(start: start, duration: duration)
    #expect(throws: FindCompatibleTeammatesError.outsideOwnAvailability) {
      try FindCompatibleTeammatesUseCase(repository: repository).execute(plan)
    }
  }

  @Test func organiserCannotRequireVoiceWhileTheirProfileDisablesIt() throws {
    let repository = TestSquadNotebookRepository(
      notebook: SquadNotebook(ownProfile: try SquadFixtures.profile(voice: false)))
    let plan = try SquadFixtures.plan()
    #expect(throws: FindCompatibleTeammatesError.ownVoiceChatUnavailable) {
      try FindCompatibleTeammatesUseCase(repository: repository).execute(plan)
    }
  }

  @Test func unreadableNotebookIsNotReportedAsNoMatchingTeammates() throws {
    let repository = TestSquadNotebookRepository()
    repository.failsToLoad = true
    let plan = try SquadFixtures.plan()
    #expect(throws: FindCompatibleTeammatesError.notebookUnavailable) {
      try FindCompatibleTeammatesUseCase(repository: repository).execute(plan)
    }
  }
}
