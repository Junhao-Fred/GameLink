import Foundation

/// Converts minutes to picker dates without device time-zone shifts.
/// The picker uses GMT as a fixed reference; play windows still use Sydney time.
nonisolated enum PlayWindowClock {
  static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  static func date(forMinute minute: Int) -> Date {
    Date(timeIntervalSinceReferenceDate: TimeInterval(minute) * 60)
  }

  static func minute(of date: Date) -> Int {
    calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }
}
