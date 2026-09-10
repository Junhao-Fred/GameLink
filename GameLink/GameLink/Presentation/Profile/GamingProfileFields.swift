import SwiftUI

struct GamingProfileFields: View {
  @Binding var form: GamingProfileForm
  let failureField: GamingProfileField?
  let failureMessage: String?
  let playerNameFocus: FocusState<Bool>.Binding

  var body: some View {
    GamingProfileDetailsSection(
      form: $form, failureField: failureField, failureMessage: failureMessage,
      playerNameFocus: playerNameFocus)
    GamingAvailabilitySection(
      form: $form, failureField: failureField, failureMessage: failureMessage)
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
    } footer: {
      Text("Use the name, server and position this player shares with teammates.")
    }
  }
}

private struct GamingAvailabilitySection: View {
  @Binding var form: GamingProfileForm
  let failureField: GamingProfileField?
  let failureMessage: String?

  var body: some View {
    Section {
      VStack(alignment: .leading) {
        Picker("Day", selection: $form.playDay) {
          Text("Choose day").tag(Optional<PlayDay>.none)
          ForEach(PlayDay.allCases, id: \.self) { day in
            Text(day.rawValue).tag(Optional(day))
          }
        }
        GamingProfileFieldError(message: failureField == .playDay ? failureMessage : nil)
      }
      DatePicker("Start time", selection: $form.startTime, displayedComponents: .hourAndMinute)
        .environment(\.calendar, GamingProfileForm.clockCalendar)
        .environment(\.timeZone, .gmt)
        .environment(\.locale, Locale(identifier: "en_GB"))
      Stepper(value: $form.durationMinutes, in: 30...180, step: 15) {
        Text("Duration: \(form.durationMinutes) minutes")
      }
      GamingProfileFieldError(message: failureField == .availability ? failureMessage : nil)
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
