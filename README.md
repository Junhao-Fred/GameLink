# GameLink

A local SwiftUI MVP for time-limited League of Legends players arranging sessions with an existing gaming circle. The app reduces repeated checks of server, position, availability and voice preferences. It prepares a conversation, not a confirmed booking.

## Scope: four Use Cases, four pages

| Bottom tab | Functional page | What the organiser does |
| --- | --- | --- |
| Plan | SessionPlanView | Sets the session window, needed position and voice requirement. |
| Matches | TeammateResultsView | Compares eligible teammates and selects a match. |
| Details | TeammateDetailsView | Checks shared time, reviews the exact proposal inline and chooses to share. |
| Profile | GamingProfileView | Saves their own profile and adds or edits permission-based teammates inline. |

These are the only four app-authored functional pages. Teammate editing and proposal review are sections within Profile and Details, not separate navigation destinations. The only sheet is the iOS system sharing interface. Missing prerequisites provide working guidance between the same four tabs.

| Use Case struct | Business responsibility |
| --- | --- |
| SaveGamingProfileUseCase | Validates and saves the organiser's identity and availability. |
| SaveTeammateContactUseCase | Records or updates a teammate after fresh permission confirmation. |
| FindCompatibleTeammatesUseCase | Finds compatible saved teammates and ranks actual shared time. |
| PrepareSquadProposalUseCase | Revalidates a selected match before producing an unconfirmed proposal. |

Each operation has a domain-specific error enum and happy-path, boundary and failure tests. Preparatory reads are methods on the relevant operation: `loadSavedProfile()`, `loadSavedTeammates()` and `loadOrganiser()`. They are not extra business workflows, and ViewModels never read files directly.

Removed from the active scope: changing teammate exclusions, standalone contact-editor and proposal-preview screens, and separate loading Use Case types. No cloud accounts, chat, payments, live player network, game-client automation or third-party dependencies are included.

## Stakeholder workflow

Save profile -> record teammates with permission -> set session conditions -> compare matches -> review shared time and proposal -> choose an external sharing destination -> confirm the exact date and arrangements in the players' existing chat.

The stakeholder framing and thirty-minute threshold are product assumptions, not interview findings or official game rules. Saved profiles are self-reported. GameLink does not verify identity, online status, skill, delivery or acceptance.

## Architecture

SwiftUI Views -> ViewModels -> Use Cases -> Domain Models / Repository -> Data.

- `App`: creates the workspace and injects one local repository.
- `Presentation`: four pages, reusable form and preview sections, draft and selection state, actionable feedback, and the system-share adapter.
- `Application`: the four business operations and typed recovery errors.
- `Domain`: validated values, the `TeammateMatchingRule` business protocol, notebook access errors and the `SquadNotebookRepository` storage contract.
- `Data`: versioned saved representations and `LocalSquadNotebookRepository`.
- `GameLinkTests`: isolated business, presentation and temporary-file persistence tests.

`GamingProfile` represents a player's declared gaming preferences. `WeeklyPlayWindow` represents recurring Sydney availability, `SquadPlan` the requested session conditions, `SquadSearch` a search snapshot, and `SquadProposal` an unconfirmed suggestion. Structs describe these values; observable ViewModel classes own changing drafts. The repository protocol allows storage to be replaced without moving business rules into Views. `SavedTeammateMatchingRule` implements the domain eligibility contract; both finding teammates and rechecking a proposal use it, so identity, server, position, voice and overlap rules stay together.

All project-authored interface text, documentation, test names and concise code comments are English. A generated DocC site is optional.

## Business rules and recovery

- Player names are trimmed, contain 1...40 characters and exclude control characters. Stable identifiers survive edits. Case-insensitive name/server duplicates are rejected.
- Teammate details require fresh permission confirmation on every add or edit. This is an organiser confirmation, not a verified consent audit.
- Weekly windows last 30...180 minutes within one day in Australia/Sydney. An end at 24:00 is allowed; crossing midnight is not.
- The whole planned session must fit the organiser's availability. Required voice chat must be supported by both players.
- Matches require the same server, needed position and at least 30 shared minutes. Results rank by longest overlap, then name and identifier.
- Proposal preparation rechecks the organiser, teammate, legacy exclusions and compatibility. Changed profiles require a fresh search. Only the actual overlap is proposed; thirty minutes does not guarantee a complete game.
- Failed saves keep the draft and previous notebook. Unreadable storage is unavailable, never a false empty state. Known notebook access failures retain their specific recovery guidance through every Use Case, including failures detected during a save.
- A teammate draft cannot be replaced by opening another contact. Organiser editing is disabled while that draft is open. Cancelling modified details requires confirmation.
- Matches retry, refresh and return actions recheck parent readiness together with results, so recovered matches can open Details. Unsaved organiser changes block planning with outdated details. Switching tabs preserves drafts; changing session conditions clears old results and selected details.
- Sharing is explicit and checked again immediately beforehand. Cancellation or failure permits retry. A completed system action is not a delivered or accepted invitation, and GameLink cannot recall an exported copy.

Profile Save remains in the top toolbar, clear of the bottom tab bar. Forms and lists use native controls, system text styles and semantic colours. Using native controls does not by itself verify physical-device behaviour or complete accessibility coverage.

## Local data compatibility

The notebook remains schema version 1 in the app's private Application Support directory. Reads validate all saved profiles, identities and windows; writes use atomic replacement and request complete file protection.

Existing `avoidedPlayerIDs` are preserved and still excluded from matching. Legacy excluded contacts remain visible and labelled in Profile. This MVP no longer changes those preferences; removing a UI feature must not silently erase saved data. There are no production sample contacts or automatic migrations that reset the notebook.

Synchronous main-actor storage is scoped to one small local notebook. There is no concurrent-writer, cloud-sync or background-processing guarantee. Physical-device file protection and backup restoration require separate validation. For a temporary read failure, unlock the device and reopen the app. An incompatible format requires a compatible app version; invalid details require a valid device backup; a missing known file must be restored before editing. The interface retains the appropriate instruction for each case. Reinstallation is not a recovery step because it can erase the only copy.

## Run in Xcode

The development environment is Xcode 26.6; the deployment target is iOS 26.5.

1. Open `GameLink/GameLink.xcodeproj`.
2. Select the `GameLink` scheme and an iPhone simulator running iOS 26.5 or later.
3. Choose Product > Run. Choose Product > Test to run `GameLinkTests`.

For a simulator build from the repository root:

```sh
xcodebuild build -project GameLink/GameLink.xcodeproj -scheme GameLink \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Tests use fresh in-memory repositories or unique temporary directories, never the installed app's notebook. Physical-device execution requires signing and a connected device.

## Verification

The test suite covers business rules, presentation state, recovery, sharing callbacks and isolated local persistence. The latest simulator run passed 289 executed test instances with zero failures; one physical-device file-protection check was skipped. A Release simulator build also passed. These checks do not verify signed-device execution or complete accessibility coverage.

Course deliverables, including the architecture diagram, reflective report, submission ZIP and local acceptance notes, are maintained separately from this code repository.

The current implementation uses the four-page scope described above. The original A1 prototype is not included in this repository, so screen and workflow alignment with A1 has not been verified. If the concept has changed, document that change alongside the original A1 materials before submission.

## Git

Repository: [Junhao-Fred/GameLink](https://github.com/Junhao-Fred/GameLink), development branch `profile-development`. Confirm assessor access to the private repository and compatibility with the deployment target.

Use Conventional Commit messages. Confirm each commit message with the owner before committing; do not push without authorization. Rewrite history only with explicit owner authorization.
