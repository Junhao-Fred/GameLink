# GameLink

An iOS app for League of Legends players to arrange sessions with their existing teammates. Profiles and teammate details are stored locally on the device.

## Features

- **Plan:** set a session time, needed position and voice preference.
- **Matches:** find saved teammates with compatible preferences and at least 30 minutes of shared availability.
- **Details:** review a proposal and share it through the iOS share sheet.
- **Profile:** save your profile and add or edit teammates with their permission.


## Run

Requires Xcode 26.6 and an iPhone or simulator running iOS 26.5 or later.

1. Open `GameLink/GameLink.xcodeproj`.
2. Select the `GameLink` scheme and a device or simulator.
3. Choose **Product > Run**. A physical device requires code signing.

## Project structure

- `App`: app entry point and dependency setup.
- `Presentation`: SwiftUI pages and ViewModels.
- `Application`: save profiles, save teammates, find matches and prepare proposals.
- `Domain`: models, business rules and repository contracts.
- `Data`: local JSON storage.
- `GameLinkTests`: business rules, presentation state, recovery and persistence tests.

## Tests

Choose **Product > Test** in Xcode. Tests use isolated storage. File protection requires a physical device and is skipped in the simulator.
