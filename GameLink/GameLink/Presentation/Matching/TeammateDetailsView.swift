import SwiftUI

/// Shows teammate details, shared time and the inline proposal preview.
struct TeammateDetailsView: View {
  @Bindable var viewModel: TeammateDetailsViewModel
  let openProfile: () -> Void
  let returnToResults: () -> Void

  var body: some View {
    List {
      switch viewModel.state {
      case .checking:
        ProgressView("Checking teammate details…")
      case .available(let proposal):
        SavedTeammateSection(profile: proposal.teammate)
        SharedSessionSection(plan: viewModel.plan, proposal: proposal)
        if let reviewedProposal = viewModel.proposalPreview {
          SquadProposalPreviewSection(viewModel: viewModel, proposal: reviewedProposal)
        } else {
          Section {
            Button(action: viewModel.reviewProposal) {
              Text("Review proposal")
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Color(.accentForeground))
            .accessibilityIdentifier("reviewSquadProposal")
          } footer: {
            Text(
              "Review the exact message before choosing where to share it. No invitation is sent automatically."
            )
          }
        }
      case .unavailable(let failure):
        Section {
          Text("Proposal unavailable").font(.headline)
          Text(failure.localizedDescription)
          Button("Check again", action: viewModel.refresh)
            .frame(minHeight: 44)
          Button("Return to results", action: returnToResults)
            .frame(minHeight: 44)
          Button("Review profile", action: openProfile)
            .frame(minHeight: 44)
        }
      }
    }
    .navigationTitle("Teammate details")
    .navigationBarTitleDisplayMode(.inline)
    .task { viewModel.refresh() }
    .sheet(item: $viewModel.shareRequest) { request in
      SquadProposalActivityView(request: request, completion: viewModel.completeSharing)
    }
  }
}

private struct SavedTeammateSection: View {
  let profile: GamingProfile

  var body: some View {
    Section {
      Text(profile.gamerTag).font(.headline)
      LabeledContent("Server", value: profile.server.rawValue)
      LabeledContent("Position", value: profile.preferredRole.rawValue)
      LabeledContent("Uses voice chat", value: profile.usesVoiceChat ? "Yes" : "No")
      Text(profile.availability.summary)
    } header: {
      Text("Saved teammate")
    } footer: {
      Text(
        "These are details recorded with permission, not verified identity or live online status.")
    }
  }
}

private struct SharedSessionSection: View {
  let plan: SquadPlan
  let proposal: SquadProposal

  var body: some View {
    Section {
      Label("\(proposal.sharedWindow.durationMinutes) minutes together", systemImage: "clock")
      Text(proposal.sharedWindow.summary)
      LabeledContent("Needed position", value: plan.neededRole.rawValue)
      LabeledContent("Voice chat", value: proposal.requiresVoiceChat ? "Required" : "Optional")
    } header: {
      Text("Compatible session")
    } footer: {
      Text(
        "Your requested session is \(plan.playWindow.summary). Only the shared time is included in the proposal. Confirm an exact date with this teammate."
      )
    }
  }
}
