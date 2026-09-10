import SwiftUI

struct GameLinkWorkspaceView: View {
  let profile: GamingProfileViewModel
  let teammateDirectory: TeammateDirectoryViewModel
  @Bindable var sessionPlan: SessionPlanViewModel
  @State private var selectedTab = GameLinkTab.find
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Find", systemImage: "person.2", value: .find) {
        NavigationStack(path: $sessionPlan.path) {
          SessionPlanView(
            viewModel: sessionPlan, openProfile: openProfile, retryProfile: refreshPlanning
          )
          .navigationDestination(for: SessionPlanDestination.self) { destination in
            switch destination {
            case .results:
              if let results = sessionPlan.results {
                TeammateResultsView(
                  viewModel: results, openProfile: openProfile,
                  openTeammate: sessionPlan.openTeammate)
              }
            case .teammateDetails:
              if let teammate = sessionPlan.selectedTeammate {
                TeammateDetailsView(
                  viewModel: teammate, openProfile: openProfile,
                  returnToResults: sessionPlan.returnToResults)
              }
            }
          }
        }
      }
      Tab("Profile", systemImage: "person.crop.circle", value: .profile) {
        NavigationStack {
          GamingProfileView(viewModel: profile, teammateDirectory: teammateDirectory)
        }
      }
    }
    .task {
      profile.loadIfNeeded()
      refreshPlanning()
    }
    .onChange(of: selectedTab) {
      if selectedTab == .find { refreshPlanning() }
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active && selectedTab == .find { refreshPlanning() }
    }
  }

  private func openProfile() { selectedTab = .profile }

  private func refreshPlanning() {
    sessionPlan.refreshProfile(hasUnsavedProfileChanges: profile.hasUnsavedChanges)
  }
}

private enum GameLinkTab: Hashable {
  case find, profile
}
