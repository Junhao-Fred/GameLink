import Foundation
import Testing

@testable import GameLink

@Suite("Using squad business operations after reopening local storage")
@MainActor
struct PersistedSquadWorkflowTests {
  @Test func theFourBusinessOperationsWorkAcrossStorageReopens() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    let organiser = try SaveGamingProfileUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    )
    .execute(SquadFixtures.draft())
    let teammate = try SaveTeammateContactUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    )
    .execute(
      SquadFixtures.draft(name: "Miko", role: .support, start: 1230, duration: 60),
      permissionConfirmed: true)
    let search = try FindCompatibleTeammatesUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    ).execute(SquadFixtures.plan())
    #expect(search.matches.map(\.id) == [teammate.id])
    let savedBeforeProposal = try Data(contentsOf: sandbox.fileURL)
    let proposal = try PrepareSquadProposalUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    )
    .execute(teammateID: teammate.id, from: search)
    #expect(proposal.organiser == organiser)
    #expect(proposal.sharedWindow.startMinute == 1230)
    #expect(proposal.sharedWindow.durationMinutes == 30)
    #expect(proposal.shareText.contains("not confirmed"))
    #expect(try Data(contentsOf: sandbox.fileURL) == savedBeforeProposal)

    try SquadFixtures.saveLegacyExclusions(
      [teammate.id], in: LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    let avoidedSearch = try FindCompatibleTeammatesUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    ).execute(SquadFixtures.plan())
    #expect(avoidedSearch.matches.isEmpty)
    #expect(throws: PrepareSquadProposalError.teammateAvoided) {
      try PrepareSquadProposalUseCase(
        repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
      )
      .execute(teammateID: teammate.id, from: search)
    }
    try SquadFixtures.saveLegacyExclusions(
      [], in: LocalSquadNotebookRepository(fileURL: sandbox.fileURL))
    let restoredSearch = try FindCompatibleTeammatesUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    ).execute(SquadFixtures.plan())
    #expect(restoredSearch.matches.map(\.id) == [teammate.id])
  }

  @Test func editingProfilesAfterReopeningPreservesIdentityAndPrivateAvoidance() throws {
    let sandbox = try SquadStorageSandbox()
    defer { sandbox.remove() }
    var original = try SquadFixtures.notebook()
    let organiser = try #require(original.ownProfile)
    let teammate = try #require(original.contacts.first)
    original.avoidedPlayerIDs = [teammate.id]
    try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).saveNotebook(original)

    let editedOrganiser = try SaveGamingProfileUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    )
    .execute(SquadFixtures.draft(name: "AlexUpdated"))
    let editedTeammate = try SaveTeammateContactUseCase(
      repository: LocalSquadNotebookRepository(fileURL: sandbox.fileURL)
    )
    .execute(
      SquadFixtures.draft(name: "MikoUpdated", role: .support), contactID: teammate.id,
      permissionConfirmed: true)
    let reopened = try LocalSquadNotebookRepository(fileURL: sandbox.fileURL).loadNotebook()
    #expect(editedOrganiser.id == organiser.id)
    #expect(editedTeammate.id == teammate.id)
    #expect(reopened.ownProfile == editedOrganiser)
    #expect(reopened.contacts == [editedTeammate])
    #expect(reopened.avoidedPlayerIDs == [teammate.id])
  }
}
