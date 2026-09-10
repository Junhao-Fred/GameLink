import SwiftUI

struct TeammateResultsView: View {
  let viewModel: TeammateResultsViewModel
  let openProfile: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    List {
      Section("Session conditions") {
        Text(viewModel.plan.playWindow.summary)
        LabeledContent("Needed position", value: viewModel.plan.neededRole.rawValue)
        LabeledContent(
          "Voice chat", value: viewModel.plan.requiresVoiceChat ? "Required" : "Optional")
      }
      switch viewModel.state {
      case .available(let search):
        Section {
          LabeledContent("Server", value: search.organiser.server.rawValue)
        }
        if search.matches.isEmpty {
          Section {
            Text("No compatible teammates").font(.headline)
            Text(
              "None of your saved teammates meet this server, position, voice preference and at least 30 shared minutes. Avoided teammates are excluded."
            )
            Button("Review session plan") { dismiss() }
              .frame(minHeight: 44)
            Button("Manage teammates in Profile", action: openProfile)
              .frame(minHeight: 44)
          }
        } else {
          Section {
            ForEach(search.matches) { match in
              TeammateMatchRow(match: match, requiresVoiceChat: search.plan.requiresVoiceChat)
            }
          } header: {
            Text("Compatible teammates (\(search.matches.count))")
          } footer: {
            Text(
              "Longest shared time first. These are saved details, not live online status. Confirm the exact date and arrangements with your teammate."
            )
          }
        }
      case .unavailable(let failure):
        Section {
          Text("Results unavailable").font(.headline)
          Text(failure.localizedDescription)
          Button("Try again") { viewModel.refresh() }
            .frame(minHeight: 44)
          Button("Review session plan") { dismiss() }
            .frame(minHeight: 44)
          Button("Review profile", action: openProfile)
            .frame(minHeight: 44)
        }
      case .unsavedProfileChanges:
        Section {
          Text("Finish your profile changes").font(.headline)
          Text(
            "Save your edits in Profile before using these results. Returning to Find will check your saved details again."
          )
          Button("Review profile", action: openProfile)
            .frame(minHeight: 44)
        }
      }
    }
    .navigationTitle("Teammate results")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Refresh results", systemImage: "arrow.clockwise") { viewModel.refresh() }
          .accessibilityIdentifier("refreshTeammateResults")
      }
    }
    .task { viewModel.refresh() }
  }
}

private struct TeammateMatchRow: View {
  let match: TeammateMatch
  let requiresVoiceChat: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(match.teammate.gamerTag).font(.headline)
      Text("\(match.teammate.server.rawValue) · \(match.teammate.preferredRole.rawValue)")
        .font(.subheadline)
      Label("\(match.sharedWindow.durationMinutes) minutes together", systemImage: "clock")
      Text(match.sharedWindow.summary).font(.callout)
      Text(
        requiresVoiceChat
          ? "Required voice chat supported"
          : (match.teammate.usesVoiceChat
            ? "Uses voice chat · optional for this plan" : "No voice chat · optional for this plan")
      )
      .font(.callout)
    }
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
  }
}
