import SwiftUI

/// Shared weekday, start-time and duration controls using Sydney time.
struct WeeklyPlayWindowFields: View {
  @Binding var day: PlayDay?
  @Binding var startTime: Date
  @Binding var durationMinutes: Int
  let title: String
  let dayFailure: String?
  let windowFailure: String?

  var body: some View {
    Section {
      VStack(alignment: .leading) {
        Picker("Day", selection: $day) {
          Text("Choose day").tag(Optional<PlayDay>.none)
          ForEach(PlayDay.allCases, id: \.self) { day in
            Text(day.rawValue).tag(Optional(day))
          }
        }
        if let dayFailure {
          Text(dayFailure).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
      }
      DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
        .environment(\.calendar, PlayWindowClock.calendar)
        .environment(\.timeZone, .gmt)
        .environment(\.locale, Locale(identifier: "en_GB"))
      Stepper(value: $durationMinutes, in: 30...180, step: 15) {
        Text("Duration: \(durationMinutes) minutes")
      }
      if let windowFailure {
        Text(windowFailure).font(.callout).fixedSize(horizontal: false, vertical: true)
      }
    } header: {
      Text(title)
    }
  }
}
