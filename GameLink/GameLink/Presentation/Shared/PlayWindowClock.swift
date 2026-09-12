import Foundation

/// Bridges minute-of-day values and picker dates without applying the device's time zone.
/// GMT is only a fixed picker reference; domain availability remains Sydney wall-clock time.
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
