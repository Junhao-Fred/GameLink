import SwiftUI

/// Collects a session plan or explains which profile step is missing.
struct SessionPlanView: View {
  @Bindable var viewModel: SessionPlanViewModel
  let openProfile: () -> Void
  let retryProfile: () -> Void

  var body: some View {
    Group {
      switch viewModel.loadState {
      case .awaitingLoad:
        ProgressView("Opening your saved availability…")
      case .ownProfileRequired:
        SessionPlanRecoveryView(
          title: "Save your profile first",
          message:
            "Add your server and weekly availability in Profile, then record teammates who agreed to share their details.",
          actionTitle: "Open Profile", action: openProfile)
      case .unsavedProfileChanges:
        SessionPlanRecoveryView(
          title: "Finish your profile changes",
          message:
            "Your profile has unsaved edits. Save them in Profile before searching so the session uses the details you expect.",
          actionTitle: "Review profile", action: openProfile)
      case .unavailable(let failure):
        SessionPlanRecoveryView(
          title: "Saved profile unavailable", message: failure.localizedDescription,
          actionTitle: "Try again", action: retryProfile)
      case .ready:
        SessionPlanFields(viewModel: viewModel, openProfile: openProfile)
      }
    }
    .navigationTitle("Session plan")
    .alert("Search not run", isPresented: $viewModel.showsSearchFailure) {
      Button("Review plan", role: .cancel) {}
    } message: {
      if let failure = viewModel.searchFailure { Text(failure.localizedDescription) }
    }
  }
}

private struct SessionPlanFields: View {
  @Bindable var viewModel: SessionPlanViewModel
  let openProfile: () -> Void

  var body: some View {
    Form {
      if let profile = viewModel.savedProfile {
        Section {
          LabeledContent("Server", value: profile.server.rawValue)
          Text(profile.availability.summary)
          Button("Edit availability in Profile", action: openProfile)
            .frame(minHeight: 44)
        } header: {
          Text("Your saved availability")
        }
      }
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Picker("Needed position", selection: $viewModel.form.neededRole) {
            Text("Choose position").tag(Optional<PreferredRole>.none)
            ForEach(PreferredRole.allCases, id: \.self) { role in
              Text(role.rawValue).tag(Optional(role))
            }
          }
          .accessibilityIdentifier("neededPosition")
          if let message = viewModel.searchFailure?.message(for: .neededRole) {
            Text(message).font(.callout)
          }
        }
        Toggle("Require voice chat", isOn: $viewModel.form.requiresVoiceChat)
          .accessibilityIdentifier("requireVoiceChat")
        if let message = viewModel.searchFailure?.message(for: .voiceChat) {
          Text(message).font(.callout)
        }
      } header: {
        Text("Teammate requirements")
      }
      WeeklyPlayWindowFields(
        day: $viewModel.form.playDay, startTime: $viewModel.form.startTime,
        durationMinutes: $viewModel.form.durationMinutes,
        title: "Session time",
        dayFailure: viewModel.searchFailure?.message(for: .playDay),
        windowFailure: viewModel.searchFailure?.message(for: .playWindow))
      Section {
        Button(action: viewModel.search) {
          Text("Find teammates").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(Color(.accentForeground))
        .disabled(!viewModel.canSearch)
        .accessibilityIdentifier("findTeammates")
        if let failure = viewModel.searchFailure, failure.field == nil {
          Text(failure.localizedDescription).font(.callout)
        }
      }
    }
  }
}

private struct SessionPlanRecoveryView: View {
  let title: String
  let message: String
  let actionTitle: String
  let action: () -> Void

  var body: some View {
    ScrollView {
      ContentUnavailableView {
        Label(title, systemImage: "person.crop.circle.badge.exclamationmark")
      } description: {
        Text(message)
      } actions: {
        Button(actionTitle, action: action)
          .buttonStyle(.borderedProminent)
          .foregroundStyle(Color(.accentForeground))
          .frame(minHeight: 44)
      }
    }
  }
}
