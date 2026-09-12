import SwiftUI

/// Connects the four tabs and guides players through missing setup steps.
struct GameLinkWorkspaceView: View {
  let profile: GamingProfileViewModel
  let teammateDirectory: TeammateDirectoryViewModel
  @Bindable var sessionPlan: SessionPlanViewModel
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView(selection: $sessionPlan.selectedTab) {
      Tab("Plan", systemImage: "calendar", value: .plan) {
        NavigationStack {
          SessionPlanView(
            viewModel: sessionPlan, openProfile: openProfile, retryProfile: refreshPlanning)
        }
      }
      Tab("Matches", systemImage: "person.2", value: .matches) {
        NavigationStack {
          if let results = sessionPlan.results {
            TeammateResultsView(
              viewModel: results, openProfile: openProfile, openPlan: openPlan,
              refreshResults: refreshPlanning, openTeammate: sessionPlan.openTeammate)
          } else {
            SquadDestinationGuidanceView(
              title: "Find teammates first", systemImage: "person.2",
              message:
                "Set your session time and needed position in Plan, then find compatible teammates.",
              actionTitle: "Open Plan", action: openPlan
            )
            .navigationTitle("Teammate results")
          }
        }
      }
      Tab("Details", systemImage: "person.text.rectangle", value: .details) {
        NavigationStack {
          if let teammate = sessionPlan.selectedTeammate {
            TeammateDetailsView(
              viewModel: teammate, openProfile: openProfile,
              returnToResults: sessionPlan.returnToResults)
          } else {
            SquadDestinationGuidanceView(
              title: "Choose a teammate", systemImage: "person.text.rectangle",
              message:
                "Open a teammate from Matches to review your shared time and prepare a proposal.",
              actionTitle: "Open Matches", action: sessionPlan.returnToResults
            )
            .navigationTitle("Teammate details")
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
    .onChange(of: sessionPlan.selectedTab) { previousTab, selectedTab in
      if previousTab == .profile && selectedTab != .profile { refreshPlanning() }
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active && sessionPlan.selectedTab != .profile { refreshPlanning() }
    }
  }

  private func openProfile() { sessionPlan.selectedTab = .profile }

  private func openPlan() { sessionPlan.selectedTab = .plan }

  private func refreshPlanning() {
    sessionPlan.refreshProfile(hasUnsavedProfileChanges: profile.hasUnsavedChanges)
  }
}

private struct SquadDestinationGuidanceView: View {
  let title: String
  let systemImage: String
  let message: String
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    ScrollView {
      ContentUnavailableView {
        Label(title, systemImage: systemImage)
      } description: {
        Text(message)
      } actions: {
        Button(actionTitle, action: action)
          .buttonStyle(.borderedProminent)
          .frame(minHeight: 44)
      }
    }
  }
}
