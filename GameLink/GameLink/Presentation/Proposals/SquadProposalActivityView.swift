import SwiftUI
import UIKit

struct SquadProposalActivityView: UIViewControllerRepresentable {
  let request: SquadProposalShareRequest
  let completion: @MainActor (UUID, SquadProposalShareOutcome) -> Void

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: [request.text], applicationActivities: nil)
    let requestID = request.id
    let completion = completion
    controller.completionWithItemsHandler = { _, completed, _, error in
      let outcome: SquadProposalShareOutcome =
        error != nil ? .failed : (completed ? .activityCompleted : .cancelled)
      Task { @MainActor in completion(requestID, outcome) }
    }
    return controller
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
