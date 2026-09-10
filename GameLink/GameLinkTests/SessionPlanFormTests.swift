import Foundation
import Testing

@testable import GameLink

@Suite("Describing a session without changing saved availability")
struct SessionPlanFormTests {
  @Test func aNewPlanUsesSavedTimeButDoesNotGuessTheNeededPosition() throws {
    let profile = try SquadFixtures.profile(day: .saturday, start: 600, duration: 90)
    let form = SessionPlanForm(profile: profile)
    #expect(form.playDay == .saturday)
    #expect(form.startMinute == 600)
    #expect(form.durationMinutes == 90)
    #expect(form.neededRole == nil)
    #expect(!form.requiresVoiceChat)
    #expect(throws: SessionPlanFormError.chooseNeededRole) { try form.makePlan() }
  }

  @Test func aSessionMustHaveAnExplicitWeekday() {
    var form = SessionPlanForm()
    form.neededRole = .support
    #expect(throws: SessionPlanFormError.choosePlayDay) { try form.makePlan() }
  }

  @Test(arguments: [(0, 30), (1260, 180), (1410, 30)])
  func validSessionBoundariesIncludeAnEndAtMidnight(start: Int, duration: Int) throws {
    var form = SessionPlanForm()
    form.playDay = .friday
    form.neededRole = .jungle
    form.startMinute = start
    form.durationMinutes = duration
    let plan = try form.makePlan()
    #expect(plan.playWindow.startMinute == start)
    #expect(plan.playWindow.durationMinutes == duration)
    #expect(plan.neededRole == .jungle)
    #expect(form.playWindowSummary == plan.playWindow.summary)
  }

  @Test(arguments: [29, 181])
  func unsupportedDurationsCannotBecomeSearchPlans(_ minutes: Int) {
    var form = SessionPlanForm()
    form.playDay = .friday
    form.neededRole = .support
    form.durationMinutes = minutes
    #expect(throws: SessionPlanFormError.invalidPlayWindow(.invalidDuration)) {
      try form.makePlan()
    }
    #expect(form.playWindowSummary == nil)
  }

  @Test func anOvernightPlanRemainsAvailableForCorrection() {
    var form = SessionPlanForm()
    form.playDay = .friday
    form.neededRole = .support
    form.startMinute = 1411
    form.durationMinutes = 30
    #expect(throws: SessionPlanFormError.invalidPlayWindow(.crossesMidnight)) {
      try form.makePlan()
    }
    #expect(form.startMinute == 1411)
  }

  @Test(arguments: [0, 59, 600, 1140, 1439])
  func theTimePickerPreservesWallClockMinutesWithoutDeviceTimeZoneConversion(_ minute: Int) {
    var form = SessionPlanForm()
    form.startMinute = minute
    let time = form.startTime
    #expect(PlayWindowClock.calendar.component(.hour, from: time) == minute / 60)
    #expect(PlayWindowClock.calendar.component(.minute, from: time) == minute % 60)
    form.startMinute = 0
    form.startTime = time
    #expect(form.startMinute == minute)
  }
}
