import SwiftUI

/// Shared profile and time fields for the organiser and teammates.
struct GamingProfileFields: View {
  @Binding var form: GamingProfileForm
  let failureField: GamingProfileField?
  let failureMessage: String?
  let playerNameFocus: FocusState<Bool>.Binding

  var body: some View {
    GamingProfileDetailsSection(
      form: $form, failureField: failureField, failureMessage: failureMessage,
      playerNameFocus: playerNameFocus)
    WeeklyPlayWindowFields(
      day: $form.playDay, startTime: $form.startTime, durationMinutes: $form.durationMinutes,
      title: "Weekly availability",
      dayFailure: failureField == .playDay ? failureMessage : nil,
      windowFailure: failureField == .availability ? failureMessage : nil)
  }
}

private struct GamingProfileDetailsSection: View {
  @Binding var form: GamingProfileForm
  let failureField: GamingProfileField?
  let failureMessage: String?
  let playerNameFocus: FocusState<Bool>.Binding

  var body: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text("Player name")
        TextField("In-game name", text: $form.gamerTag)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .submitLabel(.done)
          .focused(playerNameFocus)
          .onSubmit { playerNameFocus.wrappedValue = false }
          .accessibilityLabel("Player name")
          .accessibilityIdentifier("playerName")
        GamingProfileFieldError(message: failureField == .playerName ? failureMessage : nil)
      }
      VStack(alignment: .leading) {
        Picker("Server", selection: $form.server) {
          Text("Choose server").tag(Optional<GameServer>.none)
          ForEach(GameServer.allCases, id: \.self) { server in
            Text(server.rawValue).tag(Optional(server))
          }
        }
        GamingProfileFieldError(message: failureField == .server ? failureMessage : nil)
      }
      VStack(alignment: .leading) {
        Picker("Position", selection: $form.preferredRole) {
          Text("Choose position").tag(Optional<PreferredRole>.none)
          ForEach(PreferredRole.allCases, id: \.self) { role in
            Text(role.rawValue).tag(Optional(role))
          }
        }
        GamingProfileFieldError(message: failureField == .role ? failureMessage : nil)
      }
      Toggle("Uses voice chat", isOn: $form.usesVoiceChat)
    } header: {
      Text("League of Legends")
    }
  }
}

struct GamingProfileFieldError: View {
  let message: String?

  var body: some View {
    if let message {
      Text(message)
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
