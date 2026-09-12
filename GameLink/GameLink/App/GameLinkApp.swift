import SwiftUI

/// Connects the screens to business operations and shared local storage.
@main
struct GameLinkApp: App {
  @State private var profileViewModel: GamingProfileViewModel?
  @State private var teammateDirectory: TeammateDirectoryViewModel?
  @State private var sessionPlan: SessionPlanViewModel?
  @State private var storageSetupFailure: SquadNotebookAccessError?

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

  /// Opens local storage and prepares the workspace, or shows a retry message.
  private func openNotebook() {
    do {
      let repository = try LocalSquadNotebookRepository.applicationSupport()
      profileViewModel = GamingProfileViewModel(
        saveProfile: SaveGamingProfileUseCase(repository: repository))
      teammateDirectory = TeammateDirectoryViewModel(
        saveContact: SaveTeammateContactUseCase(repository: repository))
      sessionPlan = SessionPlanViewModel(
        findTeammates: FindCompatibleTeammatesUseCase(repository: repository),
        prepareProposal: PrepareSquadProposalUseCase(repository: repository))
      storageSetupFailure = nil
    } catch {
      storageSetupFailure = error
    }
  }
}
