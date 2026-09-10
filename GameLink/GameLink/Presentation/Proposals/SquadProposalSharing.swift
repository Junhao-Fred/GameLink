import Foundation

nonisolated struct SquadProposalShareRequest: Identifiable, Equatable, Sendable {
  let id: UUID
  let text: String
}

nonisolated enum SquadProposalShareOutcome: Equatable, Sendable {
  case activityCompleted
  case cancelled
  case failed

  var message: String {
    switch self {
    case .activityCompleted:
      "The selected share action finished. GameLink cannot verify delivery or acceptance. Confirm the date and arrangements in your chat."
    case .cancelled:
      "Sharing was cancelled. You can review this proposal and try again."
    case .failed:
      "The share action could not finish. Review the recipient and try again, or choose another app. GameLink cannot verify delivery."
    }
  }
}
