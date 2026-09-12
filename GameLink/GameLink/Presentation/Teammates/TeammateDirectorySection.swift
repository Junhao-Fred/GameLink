import SwiftUI

/// Lists saved teammates and hosts their editor within the Profile page.
struct TeammateDirectorySection: View {
  @Bindable var viewModel: TeammateDirectoryViewModel
  let canManageTeammates: Bool

  var body: some View {
    if let editor = viewModel.editor {
      TeammateContactEditorSection(viewModel: editor, directory: viewModel)
        .id(editor.id)
    } else {
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
              edit: { viewModel.beginEditingTeammate(entry) }
            )
            .disabled(!canManageTeammates)
          }
          Button(
            "Add teammate", systemImage: "person.badge.plus", action: viewModel.beginAddingTeammate
          )
          .frame(minHeight: 44)
          .disabled(!canManageTeammates)
          .accessibilityIdentifier("addTeammate")
          if let confirmation = viewModel.saveConfirmation {
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
            "Save details only with your teammate's permission. No live player directory is connected."
          )
        }
      }
    }
  }
}

private struct TeammateContactRow: View {
  let entry: TeammateDirectoryEntry
  let edit: () -> Void

  var body: some View {
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
  }
}
