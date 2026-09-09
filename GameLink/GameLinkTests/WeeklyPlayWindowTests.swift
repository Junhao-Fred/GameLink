import Testing

@testable import GameLink

@Suite("Weekly availability rules")
struct WeeklyPlayWindowTests {
  @Test(arguments: [30, 180])
  func acceptsMinimumAndMaximumPlayDurations(_ minutes: Int) throws {
    let window = try SquadFixtures.window(duration: minutes)
    #expect(window.durationMinutes == minutes)
  }

  @Test(arguments: [-1, 0, 29, 181, Int.max])
  func rejectsUnsupportedPlayDurations(_ minutes: Int) {
    #expect(throws: PlayWindowError.invalidDuration) {
      try WeeklyPlayWindow(day: .friday, startMinute: 1140, durationMinutes: minutes)
    }
  }

  @Test(arguments: [-1, 1440, Int.max])
  func rejectsStartTimesOutsideTheNamedDay(_ start: Int) {
    #expect(throws: PlayWindowError.invalidStartTime) {
      try WeeklyPlayWindow(day: .friday, startMinute: start, durationMinutes: 30)
    }
  }

  @Test func permitsEndingExactlyAtMidnightWithoutWrappingTheDay() throws {
    let window = try SquadFixtures.window(start: 1410, duration: 30)
    #expect(window.endMinute == 1440)
    #expect(window.summary == "Friday 23:30-24:00 (Australia/Sydney)")
  }

  @Test func rejectsPlayWindowsCrossingMidnight() {
    #expect(throws: PlayWindowError.crossesMidnight) {
      try SquadFixtures.window(start: 1411, duration: 30)
    }
  }

  @Test func touchingWindowsDoNotProvideSharedPlayTime() throws {
    let first = try SquadFixtures.window(start: 1140, duration: 60)
    let next = try SquadFixtures.window(start: 1200, duration: 60)
    #expect(first.sharedMinutes(with: next) == 0)
    #expect(first.sharedWindow(with: next) == nil)
  }

  @Test func differentWeekdaysDoNotOverlapEvenAtTheSameClockTime() throws {
    let friday = try SquadFixtures.window()
    let saturday = try SquadFixtures.window(day: .saturday)
    #expect(friday.sharedMinutes(with: saturday) == 0)
    #expect(friday.contains(saturday) == false)
  }
}
