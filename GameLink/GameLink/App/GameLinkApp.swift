import SwiftUI

@main
struct GameLinkApp: App {
  @State private var profileViewModel: GamingProfileViewModel?
  @State private var teammateDirectory: TeammateDirectoryViewModel?
  @State private var sessionPlan: SessionPlanViewModel?
  @State private var storageSetupFailure: SquadNotebookStorageError?

  var body: some Scene {
    WindowGroup {
      Group {
        if let profileViewModel, let teammateDirectory, let sessionPlan {
          GameLinkWorkspaceView(
            profile: profileViewModel, teammateDirectory: teammateDirectory,
            sessionPlan: sessionPlan)
        } else if let storageSetupFailure {
          NavigationStack {
            GamingProfileUnavailableView(
              message: storageSetupFailure.localizedDescription, retry: openNotebook)
          }
        } else {
          ProgressView("Opening GameLink…")
        }
      }
      .environment(\.locale, Locale(identifier: "en_AU"))
      .task {
        if profileViewModel == nil && storageSetupFailure == nil { openNotebook() }
      }
    }
  }

  private func openNotebook() {
    do {
      let repository = try LocalSquadNotebookRepository.applicationSupport()
      profileViewModel = GamingProfileViewModel(
        loadProfile: LoadGamingProfileUseCase(repository: repository),
        saveProfile: SaveGamingProfileUseCase(repository: repository))
      teammateDirectory = TeammateDirectoryViewModel(
        loadDirectory: LoadTeammateDirectoryUseCase(repository: repository),
        saveContact: SaveTeammateContactUseCase(repository: repository),
        setAvoidance: SetTeammateAvoidanceUseCase(repository: repository))
      sessionPlan = SessionPlanViewModel(
        loadProfile: LoadGamingProfileUseCase(repository: repository),
        findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
        prepareProposal: PrepareSquadProposalUseCase(repository: repository))
      storageSetupFailure = nil
    } catch {
      storageSetupFailure = error
    }
  }
}
