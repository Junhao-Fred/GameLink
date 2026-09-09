import SwiftUI

@main
struct GameLinkApp: App {
  @State private var profileViewModel: GamingProfileViewModel?
  @State private var storageSetupFailure: SquadNotebookStorageError?

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        if let profileViewModel {
          GamingProfileView(viewModel: profileViewModel)
        } else if let storageSetupFailure {
          GamingProfileUnavailableView(
            message: storageSetupFailure.localizedDescription, retry: openProfile)
        } else {
          ProgressView("Opening your profile…")
        }
      }
      .environment(\.locale, Locale(identifier: "en_AU"))
      .task {
        if profileViewModel == nil && storageSetupFailure == nil { openProfile() }
      }
    }
  }

  private func openProfile() {
    do {
      let repository = try LocalSquadNotebookRepository.applicationSupport()
      profileViewModel = GamingProfileViewModel(
        loadProfile: LoadGamingProfileUseCase(repository: repository),
        saveProfile: SaveGamingProfileUseCase(repository: repository))
      storageSetupFailure = nil
    } catch {
      storageSetupFailure = error
    }
  }
}
