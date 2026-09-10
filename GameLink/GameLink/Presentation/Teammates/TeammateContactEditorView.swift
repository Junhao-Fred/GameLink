import SwiftUI

struct TeammateContactEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @FocusState private var isPlayerNameFocused: Bool
  @State private var showsDiscardConfirmation = false
  @Bindable var viewModel: TeammateContactEditorViewModel

  var body: some View {
    NavigationStack {
      Form {
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
            if viewModel.save() {
              AccessibilityNotification.Announcement("Teammate saved on this device.").post()
              dismiss()
            }
          } label: {
            Text("Save teammate")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.borderedProminent)
          .disabled(viewModel.savedContact != nil)
          .accessibilityIdentifier("saveTeammate")
          if let failure = viewModel.saveFailure,
            failure.field == nil, failure != .contact(.permissionRequired)
          {
            GamingProfileFieldError(message: failure.localizedDescription)
          }
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(viewModel.contactID == nil ? "Add teammate" : "Edit teammate")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            if viewModel.hasUnsavedChanges { showsDiscardConfirmation = true } else { dismiss() }
          }
        }
      }
      .alert("Teammate not saved", isPresented: $viewModel.showsSaveFailure) {
        Button("Review details", role: .cancel) {
          isPlayerNameFocused = viewModel.saveFailure?.field == .playerName
        }
      } message: {
        if let failure = viewModel.saveFailure { Text(failure.localizedDescription) }
      }
      .confirmationDialog("Discard teammate changes?", isPresented: $showsDiscardConfirmation) {
        Button("Discard changes", role: .destructive) { dismiss() }
        Button("Keep editing", role: .cancel) {}
      } message: {
        Text("Your unsaved edits will be lost. Saved teammate details will stay unchanged.")
      }
    }
    .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
  }
}
