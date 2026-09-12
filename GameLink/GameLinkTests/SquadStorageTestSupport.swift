import Foundation
import Testing

@testable import GameLink

nonisolated struct SquadStorageSandbox {
  let directoryURL: URL
  var fileURL: URL { directoryURL.appending(path: "squad-notebook.json") }

  init() throws {
    directoryURL = FileManager.default.temporaryDirectory
      .appending(path: "GameLink-StorageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
  }

  func remove() {
    do {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
      try FileManager.default.removeItem(at: directoryURL)
    } catch {
      Issue.record("Could not clean up the isolated squad storage test folder: \(error)")
    }
  }

  @discardableResult
  func writeDocument(_ document: [String: Any]) throws -> Data {
    let contents = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
    try contents.write(to: fileURL)
    return contents
  }
}

nonisolated enum SquadStorageFixtures {
  static let organiserID = "11111111-1111-1111-1111-111111111111"
  static let teammateID = "22222222-2222-2222-2222-222222222222"

  static func profileDocument(
    id: String = organiserID, name: String = "Alex", role: String = "Bottom"
  ) -> [String: Any] {
    [
      "playerID": id,
      "gamerTag": name,
      "server": "Oceania",
      "preferredRole": role,
      "usesVoiceChat": true,
      "availability": [
        "day": "Friday", "startMinute": 1140, "durationMinutes": 120,
        "timeZoneIdentifier": "Australia/Sydney",
      ],
    ]
  }

  static func document() -> [String: Any] {
    [
      "schemaVersion": 1,
      "ownProfile": profileDocument(),
      "contacts": [profileDocument(id: teammateID, name: "Miko", role: "Support")],
      "avoidedPlayerIDs": [teammateID],
    ]
  }
}
