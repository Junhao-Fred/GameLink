import SwiftUI

struct GamingProfileView: View {
  @Bindable var viewModel: GamingProfileViewModel
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
          GamingProfileDetailsSection(
            form: $viewModel.form, failure: viewModel.saveFailure,
            playerNameFocus: $isPlayerNameFocused)
          GamingAvailabilitySection(form: $viewModel.form, failure: viewModel.saveFailure)
          Section {
            Button {
              isPlayerNameFocused = false
              viewModel.save()
            } label: {
              Text("Save profile")
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("saveProfile")

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
        }
        .scrollDismissesKeyboard(.interactively)
      }
    }
    .navigationTitle("Profile")
    .task { viewModel.loadIfNeeded() }
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
}

private struct GamingProfileDetailsSection: View {
  @Binding var form: GamingProfileForm
  let failure: GamingProfileSaveFailure?
  let playerNameFocus: FocusState<Bool>.Binding

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text("Player name")
        TextField("Your in-game name", text: $form.gamerTag)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.done)
          .focused(playerNameFocus)
          .onSubmit { playerNameFocus.wrappedValue = false }
          .accessibilityLabel("Player name")
          .accessibilityIdentifier("playerName")
        GamingProfileFieldError(message: failure?.message(for: .playerName))
      }
      VStack(alignment: .leading) {
        Picker("Server", selection: $form.server) {
          Text("Choose server").tag(Optional<GameServer>.none)
          ForEach(GameServer.allCases, id: \.self) { server in
            Text(server.rawValue).tag(Optional(server))
          }
        }
        GamingProfileFieldError(message: failure?.message(for: .server))
      }
      VStack(alignment: .leading) {
        Picker("Position", selection: $form.preferredRole) {
          Text("Choose position").tag(Optional<PreferredRole>.none)
          ForEach(PreferredRole.allCases, id: \.self) { role in
            Text(role.rawValue).tag(Optional(role))
          }
        }
        GamingProfileFieldError(message: failure?.message(for: .role))
      }
      Toggle("I use voice chat", isOn: $form.usesVoiceChat)
    } header: {
      Text("League of Legends")
    } footer: {
      Text("Use the name, server and position your teammates know you by.")
    }
  }
}

private struct GamingAvailabilitySection: View {
  @Binding var form: GamingProfileForm
  let failure: GamingProfileSaveFailure?

  var body: some View {
    Section {
      VStack(alignment: .leading) {
        Picker("Day", selection: $form.playDay) {
          Text("Choose day").tag(Optional<PlayDay>.none)
          ForEach(PlayDay.allCases, id: \.self) { day in
            Text(day.rawValue).tag(Optional(day))
          }
        }
        GamingProfileFieldError(message: failure?.message(for: .playDay))
      }
      DatePicker("Start time", selection: $form.startTime, displayedComponents: .hourAndMinute)
        .environment(\.calendar, GamingProfileForm.clockCalendar)
        .environment(\.timeZone, .gmt)
        .environment(\.locale, Locale(identifier: "en_GB"))
      Stepper(value: $form.durationMinutes, in: 30...180, step: 15) {
        Text("Duration: \(form.durationMinutes) minutes")
      }
      GamingProfileFieldError(message: failure?.message(for: .availability))
    } header: {
      Text("Weekly availability")
    } footer: {
      VStack(alignment: .leading, spacing: 8) {
        Text(
          "Sydney time (Australia/Sydney), regardless of your device time zone. Choose 30–180 minutes within one day."
        )
        if let summary = form.availabilitySummary { Text(summary) }
      }
    }
  }
}

private struct GamingProfileFieldError: View {
  let message: String?

  var body: some View {
    if let message {
      Text(message)
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
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
          loadProfile: LoadGamingProfileUseCase(repository: repository),
          saveProfile: SaveGamingProfileUseCase(repository: repository)))
    }
  }
#endif
