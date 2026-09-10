import Foundation

nonisolated struct SessionPlanForm: Equatable {
  var playDay: PlayDay?
  var startMinute: Int
  var durationMinutes: Int
  var neededRole: PreferredRole?
  var requiresVoiceChat = false

  init(profile: GamingProfile? = nil) {
    playDay = profile?.availability.day
    startMinute = profile?.availability.startMinute ?? 1140
    durationMinutes = profile?.availability.durationMinutes ?? 60
  }

  var startTime: Date {
    get { PlayWindowClock.date(forMinute: startMinute) }
    set { startMinute = PlayWindowClock.minute(of: newValue) }
  }

  var playWindowSummary: String? {
    guard let playDay,
      let window = try? WeeklyPlayWindow(
        day: playDay, startMinute: startMinute, durationMinutes: durationMinutes)
    else { return nil }
    return window.summary
  }

  func makePlan() throws(SessionPlanFormError) -> SquadPlan {
    guard let neededRole else { throw .chooseNeededRole }
    guard let playDay else { throw .choosePlayDay }
    let window: WeeklyPlayWindow
    do {
      window = try WeeklyPlayWindow(
        day: playDay, startMinute: startMinute, durationMinutes: durationMinutes)
    } catch { throw .invalidPlayWindow(error) }
    return SquadPlan(
      playWindow: window, neededRole: neededRole, requiresVoiceChat: requiresVoiceChat)
  }
}

nonisolated enum SessionPlanField {
  case neededRole, playDay, playWindow, voiceChat

  func hasChanged(from previous: SessionPlanForm, to current: SessionPlanForm) -> Bool {
    switch self {
    case .neededRole: previous.neededRole != current.neededRole
    case .playDay: previous.playDay != current.playDay
    case .playWindow:
      previous.playDay != current.playDay || previous.startMinute != current.startMinute
        || previous.durationMinutes != current.durationMinutes
    case .voiceChat: previous.requiresVoiceChat != current.requiresVoiceChat
    }
  }
}

nonisolated enum SessionPlanFormError: LocalizedError, Equatable {
  case chooseNeededRole
  case choosePlayDay
  case invalidPlayWindow(PlayWindowError)

  var field: SessionPlanField {
    switch self {
    case .chooseNeededRole: .neededRole
    case .choosePlayDay: .playDay
    case .invalidPlayWindow: .playWindow
    }
  }

  var errorDescription: String? {
    switch self {
    case .chooseNeededRole: "Choose the position you need a teammate to play."
    case .choosePlayDay: "Choose the weekday for this session."
    case .invalidPlayWindow(let reason): reason.errorDescription
    }
  }
}
