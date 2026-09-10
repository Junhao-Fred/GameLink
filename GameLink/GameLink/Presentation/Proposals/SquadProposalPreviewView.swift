import SwiftUI

struct SquadProposalPreviewView: View {
  @Bindable var viewModel: TeammateDetailsViewModel
  let proposal: SquadProposal
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Label("Not confirmed", systemImage: "clock")
            .font(.headline)
          Text(
            "Share directly with \(proposal.teammate.gamerTag). Check the recipient in the app you choose."
          )
        }
        Section("Message preview") {
          Text(proposal.shareText)
            .accessibilityIdentifier("squadProposalMessage")
        }
        Section {
          Button(action: viewModel.requestSharing) {
            Label("Share proposal", systemImage: "square.and.arrow.up")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.borderedProminent)
          .disabled(viewModel.shareRequest != nil)
          .accessibilityIdentifier("shareSquadProposal")
          if let outcome = viewModel.shareOutcome {
            Text(outcome.message)
              .accessibilityIdentifier("squadProposalShareOutcome")
          }
        } footer: {
          Text(
            "Includes both player names, the server, position, shared time and voice requirement. Saved details are checked again before opening sharing. A shared copy cannot be recalled by GameLink; delivery and agreement happen outside this app."
          )
        }
      }
      .navigationTitle("Proposal preview")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(item: $viewModel.shareRequest) { request in
        SquadProposalActivityView(request: request, completion: viewModel.completeSharing)
      }
    }
  }
}
