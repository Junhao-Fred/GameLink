# GameLink

A native SwiftUI iOS project for League of Legends players with limited game time who need to coordinate sessions with their existing teammates.

## Current status

The app opens a functional Profile screen connected to the local JSON repository. Players can save their own profile, maintain a teammate directory, and privately exclude or restore teammates for future searches. Teammate editing uses a sheet. Session Plan, Teammate Results, and Teammate Details remain to be built; the four-screen assessment requirement is not yet complete.

This is a fresh project, without the previous implementation or third-party dependencies. All project-authored interface text, documentation, and test names must remain in English. Swift source comments, including DocC comments, are omitted at the owner's request; domain intent is described here instead.

## Domain problem and stakeholder

The primary stakeholder is a time-limited player arranging a session within an existing gaming circle. Repeatedly checking each teammate's server, preferred role, availability, and voice-chat preference creates coordination work and can waste a limited play window.

The planned MVP will help the player identify compatible teammates and prepare a clear session proposal. This problem framing is a product hypothesis to validate with stakeholders, not a claim of completed interviews or proven results.

## MVP scope

The business rules for the following capabilities are implemented and covered by unit and local-file integration tests. Profile and teammate management have functional interfaces; matching and proposal sharing still need screens:

- Save the player's own gaming profile and availability.
- Record and update teammate details provided with their consent.
- Find teammates by server, needed role, shared play time, and voice-chat preference.
- Prepare a proposal using the actual shared time and preview it before sharing through an existing messaging app.
- Maintain a private avoid list, with a way to restore a teammate to future searches.

The local version searches the user's own teammate directory, not a live player network. Any future sample profiles must be clearly identified as examples and kept separate from user-entered contacts.

Creating or sharing a proposal is not evidence of delivery, acceptance, or a confirmed session. Players must confirm the exact date and arrangements outside GameLink. The app will not verify game-account ownership, skill, or current online status.

Out of scope: account registration, cloud sync, Firebase, live stranger matching, in-app chat, payments, leaderboards, game-history scraping, and game-client automation. Do not collect game passwords or access tokens.

## Planned screens and workflow

The completed MVP will have two top-level destinations, `Find` and `Profile`, and four functional screens:

| Screen | Purpose | Primary action |
| --- | --- | --- |
| Profile | Maintain the player's profile, teammate contacts, and private avoid list. | Save Profile |
| Session Plan | Specify the play window, needed role, and voice preference. | Find Teammates |
| Teammate Results | Show eligible teammates, shared time, and matching reasons. | Open a teammate's details |
| Teammate Details | Review the player and actual shared time before proposing a session. | Prepare Proposal |

Teammate editing and proposal preview will use focused sheets rather than additional tabs. Controls will only be added when their actions work.

Workflow: save profile -> record teammates -> set session conditions -> review matches -> check teammate details -> preview and share a proposal -> confirm externally.

Visual direction: native forms and lists, system fonts and symbols, semantic colors, a single accent color, and one primary action per screen. Support light and dark appearance, Dynamic Type, and VoiceOver. Avoid decorative dashboards, promotional banners, and unsupported status badges.

## Architecture

SwiftUI Views -> ViewModels -> Use Case structs -> Domain Models and Repository protocols -> Local data.

- Views display information and accept input; they do not implement matching rules.
- ViewModels own presentation state and invoke business operations.
- Use Cases validate and execute domain operations, with typed errors and recovery messages.
- Domain value types describe players, roles, servers, play windows, matches, and proposals.
- Repository implementations handle local storage independently of matching decisions.

Implemented Use Case structs and their test suites:

| Business operation | Use Case | Test suite |
| --- | --- | --- |
| Save the organiser's profile | `SaveGamingProfileUseCase` | `SaveGamingProfileTests` |
| Record or update a teammate | `SaveTeammateContactUseCase` | `SaveTeammateContactTests` |
| Find compatible teammates | `FindCompatibleTeammatesUseCase` | `FindCompatibleTeammatesTests` |
| Prepare an unconfirmed proposal | `PrepareSquadProposalUseCase` | `PrepareSquadProposalTests` |
| Avoid or restore a teammate | `SetTeammateAvoidanceUseCase` | `SetTeammateAvoidanceTests` |
| Open the player's saved profile | `LoadGamingProfileUseCase` | `LoadGamingProfileTests` |
| Open saved teammates and their private search preferences | `LoadTeammateDirectoryUseCase` | `LoadTeammateDirectoryTests` |

Every Use Case has a typed error enum with English recovery guidance, success tests, and failure tests. `WeeklyPlayWindowTests` separately covers time validation and overlap boundaries.

`LocalSquadNotebookRepository` implements `SquadNotebookRepository` using an atomic JSON file in the app's private Application Support directory. Persistence-specific Codable representations remain in the Data layer; domain models do not depend on a serialization format. Every decoded profile and play window passes through its existing validated initializer.

Current source folders:

- `GameLink/GameLink/App`: application entry point.
- `GameLink/GameLink/Presentation/Profile`: the personal profile screen, shared player fields, form validation, and profile ViewModel.
- `GameLink/GameLink/Presentation/Teammates`: the directory section, teammate editor sheet, and their ViewModels.
- `GameLink/GameLink/Domain`: immutable validated profiles and play windows, squad models, and the notebook repository contract.
- `GameLink/GameLink/Application`: the seven business Use Cases.
- `GameLink/GameLink/Data`: local notebook storage, versioned saved representations, and storage recovery errors.
- `GameLink/GameLinkTests`: independent business suites, a test-only in-memory notebook, and isolated real-file integration tests.

Value types describe domain records. Main-actor-isolated Use Cases and the repository contract keep each synchronous read/validate/save operation together. The test repository is a reference type because multiple Use Cases share a notebook during a workflow. Pure domain values are nonisolated and do not depend on SwiftUI. No inheritance or third-party abstraction framework is needed.

## Implemented business rules

These are explicit MVP product rules to validate with stakeholders, not official game rules:

- Player names are trimmed and contain 1...40 characters without embedded control characters. Names and servers are self-reported, not verified account identities.
- Profile edits retain a stable local player identifier. A case-insensitive name/server pair identifies a likely duplicate within this small directory; editing cannot overwrite another contact.
- Teammate recording requires confirmation that permission was obtained. This confirmation is not an independent consent audit.
- Each weekly window lasts 30...180 minutes, stays within one day, and uses `Australia/Sydney` wall-clock time. Ending at 24:00 is permitted; crossing midnight is not. A recurring weekday is not a booked calendar date.
- A plan must fit entirely inside the organiser's availability. Required voice chat must also be supported by the organiser.
- A teammate must match the server and requested role, meet the voice requirement, and share at least 30 minutes. The organiser and privately avoided players are excluded.
- Results rank by longer shared time, then by stable name/identifier order. No matches is a valid empty result, distinct from unreadable saved data.
- Preparing a proposal rechecks the saved organiser, teammate, and avoid list. Changed profiles require a new search. Shared time is recalculated rather than trusted from a cached result.
- Proposals are drafts only: no message is transmitted, no session is accepted, and users must confirm the exact date externally. Thirty minutes of overlap does not guarantee a complete game.
- Avoidance is private and reversible. Repeating the current preference performs no write; failed saves leave the previous notebook unchanged according to the repository contract.

## Local storage and recovery

The production factory is `LocalSquadNotebookRepository.applicationSupport()`. It resolves `GameLink/squad-notebook.json` under the system-provided Application Support location; no computer username or absolute development-machine path is embedded. Tests inject a file URL inside a newly created temporary folder instead.

- A genuinely missing file returns an empty notebook without creating data. The first successful save creates the required directory and file; there are no sample contacts or automatic seed data.
- The format has `schemaVersion: 1`, an optional `ownProfile`, ordered `contacts`, and `avoidedPlayerIDs`. Profiles store a stable UUID, name, server, role, weekly availability, and voice preference. Availability explicitly stores `Australia/Sydney`; other time zones are rejected rather than silently reinterpreted.
- Saved server, role, and weekday strings are part of version 1 of the format. Renaming these stored values requires an explicit migration, not a UI-only string change.
- Decoding rejects invalid names, untrimmed names, missing profile fields, unknown enum values, invalid time windows, duplicate player identifiers, duplicate name/server pairs, contacts without an organiser, and orphaned or repeated avoidance identifiers. It does not repair these silently or invent defaults.
- The version is checked before the rest of the document. Unsupported formats and damaged files block both reads and replacement saves. The original bytes remain in place; this stage provides preservation and recovery guidance, not an in-app backup restoration tool.
- Each save validates the proposed notebook and re-reads the current file before replacing it. Foundation's [atomic write option](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomic) writes an auxiliary file before replacing the destination. A failed save must not publish changes or truncate the previous notebook.
- The repository has no cached copy of player details. Reads see the current file. If a repository has already seen a saved file and that file disappears, it reports missing saved details rather than creating an empty replacement. A new process cannot distinguish an externally deleted file from a true first launch; cross-process deletion recovery needs a separate backup strategy.
- The write requests [complete file protection](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/completefileprotection). This is an operating-system protection option, not application-managed encryption. Device lock/unlock behavior still requires physical-device validation.
- Operations remain synchronous and main-actor-isolated for this small, single-process teammate directory. There is no app-group sharing, cross-process writer coordination, cloud sync, or background writing. Larger datasets would require revisiting this execution model.

Do not delete app data or reinstall the app to recover an unreadable notebook: that can erase the only saved copy. Restore a known-good device backup or use an app version compatible with the saved format. GameLink does not create its own backups; system device-backup behavior is not configured or validated by this stage.

## Run locally

The current development environment is Xcode 26.6. The project deployment target is iOS 26.5.

1. Open `GameLink/GameLink.xcodeproj` in Xcode.
2. Select the `GameLink` scheme.
3. Select an installed iPhone simulator running iOS 26.5 or later.
4. Choose Product > Run.

No Apple developer account is required for simulator execution. Running on a physical device requires device setup and signing; simulator checks do not establish real-device compatibility.

From the repository root, build for the simulator without signing:

```sh
xcodebuild build \
  -project GameLink/GameLink.xcodeproj \
  -scheme GameLink \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

## Run business tests

In Xcode, select the `GameLink` scheme and an iPhone simulator, then choose Product > Test. The `GameLinkTests` target uses Swift Testing; individual suites and parameter cases are also available in the Test navigator.

From the repository root, for the installed iPhone 17 Pro / iOS 26.5 simulator:

```sh
xcodebuild test \
  -project GameLink/GameLink.xcodeproj \
  -scheme GameLink \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO
```

Business unit tests use a fresh in-memory repository for each scenario. Storage and workflow integration tests use a unique temporary directory per invocation, with cleanup on exit; they never load or overwrite the app's real notebook. Permission changes in these isolated directories exercise actual file-read and atomic-write failures. Tests do not access live accounts, send messages, or depend on test execution order.

Storage tests reopen new repository instances to verify that identities, contact order, avoidance, matching, and unconfirmed proposals use data read back from disk. Repository reopening tests alone do not establish end-to-end app termination/relaunch behavior.

## Profile and teammate management

The app entry point creates profile and directory ViewModels using the same local repository. Each ViewModel invokes named Use Cases; Views never read or write the notebook directly. `TeammateDirectoryEntry` represents one saved teammate together with the organiser's private search preference. Its identity comes from the saved contact, so changing a name does not replace a row or reset avoidance.

- Save the organiser's profile before adding teammates. Unsaved profile edits must also be saved before managing the directory, so teammate validation uses the identity visible to the organiser.
- Tap a teammate to edit their saved details. Add and edit use the same player fields as the organiser's form, with a separate draft and separate validation state.
- Permission starts unchecked for every editing session. Confirm that the teammate agreed to storage of these details before saving. This is a user confirmation, not a verified permission record or an automatic notification.
- A successful save closes the sheet and reloads the directory. An unsuccessful save leaves the draft open and keeps existing stored details unchanged. Field errors remain visible after dismissing the alert and clear when the affected input changes.
- Cancel asks before discarding modified fields. Interactive sheet dismissal is disabled while a draft has unsaved changes. Merely opening or editing the form performs no write.
- Use a teammate's search-preference menu to exclude or restore them. Avoided teammates remain visible and editable; their saved details are not deleted. Search eligibility is still determined by the matching Use Case when search screens are connected.
- Unreadable storage is shown as unavailable, with a retry action; it is never presented as an empty directory. There are no seeded contacts in the production app.

## Remaining assessment work

- Complete Session Plan, Teammate Results, and Teammate Details, including proposal preview and system sharing.
- Present the existing domain errors with useful recovery actions in the remaining screens.
- Validate complete UI workflows, app termination/relaunch, and physical-device file protection; the minimum Use Case and unit-test counts are already represented in code.
- Produce a one-page human-system architecture diagram in PDF or PNG, showing layers, responsibility boundaries, and the main data flow.
- Write a 600-800-word English reflective report, grounded in actual design and validation evidence, and export it as PDF.
- Validate the working app in Xcode and package the project for submission.
- Obtain owner approval of each new commit message before committing; obtain authorization before pushing further changes.

Next development stage: implement Session Plan and Teammate Results using the saved profile and teammate directory, then connect Teammate Details and proposal sharing.

## Foundation validation

On September 8, 2026, the simulator build and launch passed with Xcode 26.6 on an iPhone 17 Pro simulator running iOS 26.5. Swift formatting checks passed, and no Chinese characters were found in project source, resources, or documentation, excluding Git internals and local Xcode user state.

Light and dark appearance were visually checked. The largest Dynamic Type size wraps the text, but complete scrolling remains unverified because automated gestures did not move the simulator content. Small-phone, iPad, physical-device, and spoken VoiceOver checks remain pending. This describes the unchanged informational screen, not future functional screens.

Stage 2 adds 58 test methods, expanded into 75 test instances through parameterized cases. Two complete simulator runs passed with no failures or skipped tests. A temporary mutation from "at least 30 minutes" to "more than 30 minutes" correctly failed the boundary test; the correct rule was restored before the final passing run. Swift formatting and the English-only source check also passed. Results validate the domain layer and test-repository behavior, not real disk persistence or a completed MVP.

## Stage 3 validation

On September 9, 2026, the full Xcode simulator run passed 91 test methods, expanded into 151 executed test instances, with zero failures. One additional physical-device file-protection test is explicitly skipped on Simulator. The project now contains 92 test methods in total.

New real-file tests cover fresh storage, repeated reads, a separately specified version-1 document, profile and availability validation, identity and avoidance consistency, nested directory creation, complete replacement writes, damaged or unsupported data preservation, read failures, failed first saves, failed replacement saves, and successful retry. A workflow test reopens storage between all five business operations; another verifies stable identities and avoidance after profile edits. Each test uses its own temporary directory and cleans it up.

An initial file-protection attribute assertion failed because the iOS 26.5 simulator returned no protection attribute. An independent direct Foundation write reproduced the same missing attribute, without using the GameLink repository. The attribute assertion is now a separate device-only test, not a simulated security pass. Actual locked-device access, process termination/relaunch, device-backup restoration, and interruption during the operating system's replacement operation remain unverified.

Swift formatting, whitespace, English-only content, absence of Swift source comments, and absence of embedded local development paths were checked. Existing domain models, Use Cases, and the informational SwiftUI screen were not changed. No new dependency was added.

## Teammate management validation

On September 10, 2026, the updated app compiled and its full simulator test run passed 132 test methods, with one existing physical-device file-protection test skipped. Parameterized cases expanded the passing methods into 201 executed test instances. The three new teammate suites add 21 test methods covering directory loading, permission, duplicate contacts, draft preservation, midnight boundaries, stable identity, avoidance, retry, and disk reopening.

The profile save and empty teammate directory were inspected on a separate test simulator using fictional details. That inspection exposed repeated sheet presentation from a Form section. The sheet and directory alerts were moved to the enclosing Form. Follow-up UI checks confirmed that the corrected sheet opens, missing permission blocks saving without losing the draft, and a permitted save adds the teammate to the directory. Editing a name updates the existing row, permission starts unchecked on each edit, and discarding an edited voice preference leaves the saved preference unchanged.

The avoidance menu was exercised in both directions. After terminating and relaunching the app, the edited teammate and exclusion state were still present; restoring inclusion removed the exclusion label. Light appearance at the default text size and dark appearance at the largest Dynamic Type size were visually checked. The profile and teammate forms could be scrolled through to the directory, permission control, and save button, with long labels wrapping instead of being clipped. The test simulator was returned to light appearance and the default text size afterward.

The final full simulator test run passed with 201 passing test instances, one device-only test skipped, and no failures. Small-phone, iPad, physical-device, spoken VoiceOver, and interrupted-write behavior remain unverified. Simulator touch-flow checks do not establish physical-device file-protection behavior.

## Git

Development continues locally on `profile-development`. The remote `main` branch does not yet include the profile screens or teammate-management changes. Documentation and storage tests accompany the local implementation.

Keep further work local until approved. Confirm each new commit message with the owner before committing; do not push without authorization. Do not restore the previous project's Git history or manufacture retrospective commits.

The remote is the private repository [Junhao-Fred/GameLink](https://github.com/Junhao-Fred/GameLink). Before any authorized push, verify the active account is `Junhao-Fred` and verify the destination.
