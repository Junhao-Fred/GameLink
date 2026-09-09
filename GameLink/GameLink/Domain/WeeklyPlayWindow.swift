import Foundation

nonisolated enum PlayDay: String, CaseIterable, Sendable {
  case monday = "Monday"
  case tuesday = "Tuesday"
  case wednesday = "Wednesday"
  case thursday = "Thursday"
  case friday = "Friday"
  case saturday = "Saturday"
  case sunday = "Sunday"
}

nonisolated struct WeeklyPlayWindow: Equatable, Sendable {
  static let timeZoneIdentifier = "Australia/Sydney"
  static let minimumSharedMinutes = 30

  let day: PlayDay
  let startMinute: Int
  let durationMinutes: Int

  var endMinute: Int { startMinute + durationMinutes }

  init(day: PlayDay, startMinute: Int, durationMinutes: Int) throws(PlayWindowError) {
    guard (0..<1440).contains(startMinute) else { throw .invalidStartTime }
    guard (30...180).contains(durationMinutes) else { throw .invalidDuration }
    guard startMinute <= 1440 - durationMinutes else { throw .crossesMidnight }
    self.day = day
    self.startMinute = startMinute
    self.durationMinutes = durationMinutes
  }

  func contains(_ session: WeeklyPlayWindow) -> Bool {
    day == session.day && startMinute <= session.startMinute && endMinute >= session.endMinute
  }

  func sharedMinutes(with other: WeeklyPlayWindow) -> Int {
    guard day == other.day else { return 0 }
    return max(0, min(endMinute, other.endMinute) - max(startMinute, other.startMinute))
  }

  func sharedWindow(with other: WeeklyPlayWindow) -> WeeklyPlayWindow? {
    let minutes = sharedMinutes(with: other)
    guard minutes >= Self.minimumSharedMinutes else { return nil }
    return WeeklyPlayWindow(
      validatedDay: day, startMinute: max(startMinute, other.startMinute),
      durationMinutes: minutes)
  }

  var summary: String {
    "\(day.rawValue) \(clockTime(startMinute))-\(clockTime(endMinute)) (\(Self.timeZoneIdentifier))"
  }

  private init(validatedDay: PlayDay, startMinute: Int, durationMinutes: Int) {
    day = validatedDay
    self.startMinute = startMinute
    self.durationMinutes = durationMinutes
  }

  private func clockTime(_ minute: Int) -> String {
    String(format: "%02d:%02d", minute / 60, minute % 60)
  }
}

nonisolated enum PlayWindowError: LocalizedError, Equatable, Sendable {
  case invalidStartTime
  case invalidDuration
  case crossesMidnight

  var errorDescription: String? {
    switch self {
    case .invalidStartTime:
      "Choose a start time between 00:00 and 23:59."
    case .invalidDuration:
      "Choose a play window between 30 and 180 minutes."
    case .crossesMidnight:
      "Overnight play windows are not supported yet. Choose an earlier start or a shorter duration."
    }
  }
}
