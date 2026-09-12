import SwiftUI

/// Opens an authenticated workspace or the existing local prototype.
@main
struct GameLinkApp: App {
  @State private var account: AccountViewModel
  @State private var usesLocalMode = false

  init() {
    let service = LocalAccountService()
    _account = State(
      initialValue: AccountViewModel(
        registerAccount: RegisterLocalAccountUseCase(service: service),
        signInAccount: SignInLocalAccountUseCase(service: service),
        signOutAccount: SignOutLocalAccountUseCase(service: service),
        restoreSession: RestoreLocalSessionUseCase(service: service)))
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if account.isRestoring {
          ProgressView("Opening GameLink…")
        } else if account.identity != nil || usesLocalMode {
          LocalWorkspaceView(account: account, leaveLocalMode: { usesLocalMode = false })
            .id(account.identity?.id.uuidString ?? "local")
        } else {
          AccountAccessView(
            model: account,
            openLocalMode: {
              account.resetForm()
              usesLocalMode = true
            })
        }
      }
      .environment(\.locale, Locale(identifier: "en_AU"))
      .task { await account.restore() }
    }
  }
}

private struct LocalWorkspaceView: View {
  let account: AccountViewModel
  let leaveLocalMode: () -> Void
  @State private var profileViewModel: GamingProfileViewModel?
  @State private var teammateDirectory: TeammateDirectoryViewModel?
  @State private var sessionPlan: SessionPlanViewModel?
  @State private var storageSetupFailure: SquadNotebookAccessError?

  var body: some View {
    Group {
      if let profileViewModel, let teammateDirectory, let sessionPlan {
        GameLinkWorkspaceView(
          profile: profileViewModel, teammateDirectory: teammateDirectory,
          sessionPlan: sessionPlan, account: account, leaveLocalMode: leaveLocalMode)
      } else if let storageSetupFailure {
        NavigationStack {
          GamingProfileUnavailableView(
            message: storageSetupFailure.localizedDescription, retry: openNotebook
          )
          .toolbar {
            Button("Back to sign in") {
              if account.identity == nil {
                leaveLocalMode()
              } else {
                Task { await account.signOut() }
              }
            }
          }
        }
      } else {
        ProgressView("Opening GameLink…")
      }
    }
    .task {
      if profileViewModel == nil && storageSetupFailure == nil { openNotebook() }
    }
  }

  /// Opens local storage and prepares the workspace, or shows a retry message.
  private func openNotebook() {
    do {
      let repository = try LocalSquadNotebookRepository.applicationSupport(
        accountID: account.identity?.id)
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
