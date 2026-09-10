import SwiftUI

struct TeammateDirectorySection: View {
  @Bindable var viewModel: TeammateDirectoryViewModel
  let canManageTeammates: Bool

  var body: some View {
    Section {
      switch viewModel.loadState {
      case .awaitingLoad:
        ProgressView("Opening your teammates…")
      case .unavailable(.ownProfileRequired):
        Text("Save your own profile before adding teammates.")
      case .unavailable(let failure):
        Text("Teammates unavailable").font(.headline)
        Text(failure.localizedDescription)
        Button("Try again", action: viewModel.reload)
      case .ready:
        if viewModel.entries.isEmpty {
          Text("No teammates saved yet.")
        }
        ForEach(viewModel.entries) { entry in
          TeammateContactRow(
            entry: entry,
            edit: { viewModel.beginEditingTeammate(entry) },
            changeAvoidance: { viewModel.changeAvoidance(for: entry) }
          )
          .disabled(!canManageTeammates)
        }
        Button(
          "Add teammate", systemImage: "person.badge.plus", action: viewModel.beginAddingTeammate
        )
        .frame(minHeight: 44)
        .disabled(!canManageTeammates)
        .accessibilityIdentifier("addTeammate")
        if let confirmation = viewModel.preferenceConfirmation {
          Text(confirmation).font(.callout)
        }
      }
    } header: {
      Text("Teammates")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        if !canManageTeammates && viewModel.loadState == .ready {
          Text("Save your profile changes before managing teammates.")
        }
        Text(
          "Avoided teammates stay in this list. They are excluded from your searches and are not notified."
        )
      }
    }
  }
}

private struct TeammateContactRow: View {
  let entry: TeammateDirectoryEntry
  let edit: () -> Void
  let changeAvoidance: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button(action: edit) {
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.contact.profile.gamerTag).font(.headline)
          Text(
            "\(entry.contact.profile.server.rawValue) · \(entry.contact.profile.preferredRole.rawValue)"
          )
          .font(.subheadline)
          if entry.isAvoided {
            Label("Excluded from searches", systemImage: "eye.slash")
              .font(.footnote)
          }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityElement(children: .combine)
      .accessibilityHint("Edit this teammate's saved details.")
      Menu {
        Button(
          entry.isAvoided ? "Include in searches" : "Avoid in searches",
          systemImage: entry.isAvoided ? "eye" : "eye.slash",
          action: changeAvoidance)
      } label: {
        Image(systemName: "ellipsis")
          .frame(minWidth: 44, minHeight: 44)
      }
      .accessibilityLabel("Search preference for \(entry.contact.profile.gamerTag)")
      .accessibilityValue(entry.isAvoided ? "Excluded" : "Included")
    }
  }
}
