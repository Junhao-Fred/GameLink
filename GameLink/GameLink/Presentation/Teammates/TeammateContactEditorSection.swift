import SwiftUI

/// Edits teammate details in Profile, with permission, save and cancel controls.
struct TeammateContactEditorSection: View {
  @FocusState private var isPlayerNameFocused: Bool
  @Bindable var viewModel: TeammateContactEditorViewModel
  let directory: TeammateDirectoryViewModel

  var body: some View {
    Group {
      Section {
        Text(viewModel.contactID == nil ? "Add teammate" : "Edit teammate")
          .font(.headline)
        Text("Finish or cancel these teammate details before editing your own profile.")
      }
      GamingProfileFields(
        form: $viewModel.form,
        failureField: viewModel.saveFailure?.field,
        failureMessage: viewModel.saveFailure?.localizedDescription,
        playerNameFocus: $isPlayerNameFocused)
      Section {
        Toggle(
          "My teammate agreed to me keeping these details", isOn: $viewModel.permissionConfirmed
        )
        .accessibilityIdentifier("teammatePermission")
        if viewModel.saveFailure == .contact(.permissionRequired) {
          GamingProfileFieldError(message: viewModel.saveFailure?.localizedDescription)
        }
      } header: {
        Text("Permission")
      } footer: {
        Text("Confirm permission each time you save. These details stay on this device.")
      }
      Section {
        Button {
          isPlayerNameFocused = false
          directory.saveEditor()
        } label: {
          Text("Save teammate")
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(Color(.accentForeground))
        .disabled(viewModel.savedContact != nil)
        .accessibilityIdentifier("saveTeammate")
        .alert("Teammate not saved", isPresented: $viewModel.showsSaveFailure) {
          Button("Review details", role: .cancel) {
            isPlayerNameFocused = viewModel.saveFailure?.field == .playerName
          }
        } message: {
          if let failure = viewModel.saveFailure { Text(failure.localizedDescription) }
        }
        Button("Cancel teammate edit", action: directory.requestCancelEditing)
          .frame(minHeight: 44)
        if let failure = viewModel.saveFailure,
          failure.field == nil, failure != .contact(.permissionRequired)
        {
          GamingProfileFieldError(message: failure.localizedDescription)
        }
      }
    }
  }
}
