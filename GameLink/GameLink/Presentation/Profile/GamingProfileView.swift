import SwiftUI

/// Lets the organiser maintain their profile and permission-based teammates on one page.
struct GamingProfileView: View {
  @Bindable var viewModel: GamingProfileViewModel
  @Bindable var teammateDirectory: TeammateDirectoryViewModel
  @FocusState private var isPlayerNameFocused: Bool

  var body: some View {
    Group {
      switch viewModel.loadState {
      case .awaitingLoad:
        ProgressView("Opening your profile…")
      case .unavailable(let failure):
        GamingProfileUnavailableView(
          message: failure.localizedDescription, retry: viewModel.loadIfNeeded)
      case .ready:
        Form {
          GamingProfileFields(
            form: $viewModel.form,
            failureField: viewModel.saveFailure?.field,
            failureMessage: viewModel.saveFailure?.localizedDescription,
            playerNameFocus: $isPlayerNameFocused
          )
          .disabled(teammateDirectory.editor != nil)
          Section {
            if let failure = viewModel.saveFailure, failure.field == nil {
              Text(failure.localizedDescription)
                .font(.callout)
            } else if viewModel.showsSaveConfirmation {
              Label("Profile saved on this device.", systemImage: "checkmark.circle")
                .font(.callout)
            } else if viewModel.hasUnsavedChanges {
              Text("Unsaved changes")
                .font(.callout)
            }
          } footer: {
            Text("Your profile stays on this device. It is not published or sent to other players.")
          }
          TeammateDirectorySection(
            viewModel: teammateDirectory, canManageTeammates: viewModel.canManageTeammates)
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(
          "Discard teammate changes?", isPresented: $teammateDirectory.showsDiscardConfirmation
        ) {
          Button("Discard changes", role: .destructive, action: teammateDirectory.discardEditor)
          Button("Keep editing", role: .cancel) {}
        } message: {
          Text("Your unsaved edits will be lost. Saved teammate details will stay unchanged.")
        }
        .onChange(of: teammateDirectory.saveConfirmation) { _, confirmation in
          if let confirmation { AccessibilityNotification.Announcement(confirmation).post() }
        }
      }
    }
    .navigationTitle("Profile")
    .toolbar {
      // Keep saving reachable while the form scrolls behind the floating tab bar.
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", action: saveProfile)
          .disabled(!viewModel.canSave || teammateDirectory.editor != nil)
          .accessibilityLabel("Save profile")
          .accessibilityIdentifier("saveProfile")
      }
    }
    .task { viewModel.loadIfNeeded() }
    .onChange(of: viewModel.savedProfile, initial: true) { teammateDirectory.reload() }
    .alert("Profile not saved", isPresented: $viewModel.showsSaveFailure) {
      Button("Review profile", role: .cancel) {
        isPlayerNameFocused = viewModel.saveFailure?.field == .playerName
      }
    } message: {
      if let failure = viewModel.saveFailure { Text(failure.localizedDescription) }
    }
    .onChange(of: viewModel.showsSaveConfirmation) { _, isSaved in
      if isSaved {
        AccessibilityNotification.Announcement("Profile saved on this device.").post()
      }
    }
  }

  private func saveProfile() {
    isPlayerNameFocused = false
    viewModel.save()
  }
}

struct GamingProfileUnavailableView: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("Profile unavailable", systemImage: "person.crop.circle.badge.exclamationmark")
    } description: {
      Text(message)
    } actions: {
      Button("Try again", action: retry)
        .buttonStyle(.borderedProminent)
    }
  }
}

#if DEBUG
  @MainActor
  private final class PreviewSquadNotebookRepository: SquadNotebookRepository {
    private var notebook = SquadNotebook()

    func loadNotebook() throws -> SquadNotebook { notebook }

    func saveNotebook(_ notebook: SquadNotebook) throws { self.notebook = notebook }
  }

  #Preview("Profile") {
    let repository = PreviewSquadNotebookRepository()
    NavigationStack {
      GamingProfileView(
        viewModel: GamingProfileViewModel(
          saveProfile: SaveGamingProfileUseCase(repository: repository)),
        teammateDirectory: TeammateDirectoryViewModel(
          saveContact: SaveTeammateContactUseCase(repository: repository)))
    }
  }
#endif
