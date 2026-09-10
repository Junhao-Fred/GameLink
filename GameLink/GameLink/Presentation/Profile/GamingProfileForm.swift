import Foundation

nonisolated struct GamingProfileForm: Equatable {
  var gamerTag: String
  var server: GameServer?
  var preferredRole: PreferredRole?
  var playDay: PlayDay?
  var startMinute: Int
  var durationMinutes: Int
  var usesVoiceChat: Bool

  static let clockCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  init(profile: GamingProfile? = nil) {
    gamerTag = profile?.gamerTag ?? ""
    server = profile?.server
    preferredRole = profile?.preferredRole
    playDay = profile?.availability.day
    startMinute = profile?.availability.startMinute ?? 1140
    durationMinutes = profile?.availability.durationMinutes ?? 60
    usesVoiceChat = profile?.usesVoiceChat ?? false
  }

  var startTime: Date {
    get { Date(timeIntervalSinceReferenceDate: TimeInterval(startMinute) * 60) }
    set {
      startMinute =
        Self.clockCalendar.component(.hour, from: newValue) * 60
        + Self.clockCalendar.component(.minute, from: newValue)
    }
  }

  var availabilitySummary: String? {
    guard let playDay,
      let window = try? WeeklyPlayWindow(
        day: playDay, startMinute: startMinute, durationMinutes: durationMinutes)
    else { return nil }
    return window.summary
  }

  func makeDraft() throws(GamingProfileFormError) -> GamingProfileDraft {
    guard let server else { throw .chooseServer }
    guard let preferredRole else { throw .chooseRole }
    guard let playDay else { throw .choosePlayDay }
    let availability: WeeklyPlayWindow
    do {
      availability = try WeeklyPlayWindow(
        day: playDay, startMinute: startMinute, durationMinutes: durationMinutes)
    } catch { throw .invalidPlayWindow(error) }
    return GamingProfileDraft(
      gamerTag: gamerTag, server: server, preferredRole: preferredRole,
      availability: availability, usesVoiceChat: usesVoiceChat)
  }
}

nonisolated enum GamingProfileField {
  case playerName, server, role, playDay, availability

  func hasChanged(from previous: GamingProfileForm, to current: GamingProfileForm) -> Bool {
    switch self {
    case .playerName:
      previous.gamerTag != current.gamerTag || previous.server != current.server
    case .server: previous.server != current.server
    case .role: previous.preferredRole != current.preferredRole
    case .playDay: previous.playDay != current.playDay
    case .availability:
      previous.startMinute != current.startMinute
        || previous.durationMinutes != current.durationMinutes
    }
  }
}

nonisolated enum GamingProfileFormError: LocalizedError, Equatable {
  case chooseServer
  case chooseRole
  case choosePlayDay
  case invalidPlayWindow(PlayWindowError)

  var field: GamingProfileField {
    switch self {
    case .chooseServer: .server
    case .chooseRole: .role
    case .choosePlayDay: .playDay
    case .invalidPlayWindow: .availability
    }
  }

  var errorDescription: String? {
    switch self {
    case .chooseServer: "Choose the player's server before saving."
    case .chooseRole: "Choose the player's preferred position before saving."
    case .choosePlayDay: "Choose the weekday this player is usually available."
    case .invalidPlayWindow(let reason): reason.errorDescription
    }
  }
}
