# GameLink

A native SwiftUI iOS project for League of Legends players with limited game time who need to coordinate sessions with their existing teammates.

## Current status

Stage 2: domain models, five business Use Cases, and a native Swift Testing target are implemented. The app still displays the Stage 1 informational home screen: the business layer is not connected to a UI or production storage yet. Profile editing, teammate search, and sharing are not available through the app. The home screen does not count toward the four functional screens required by the assessment.

This is a fresh project, without the previous implementation or third-party dependencies. All project-authored interface text, comments, documentation, and test names must remain in English.

## Domain problem and stakeholder

The primary stakeholder is a time-limited player arranging a session within an existing gaming circle. Repeatedly checking each teammate's server, preferred role, availability, and voice-chat preference creates coordination work and can waste a limited play window.

The planned MVP will help the player identify compatible teammates and prepare a clear session proposal. This problem framing is a product hypothesis to validate with stakeholders, not a claim of completed interviews or proven results.

## MVP scope

The business rules for the following capabilities are implemented and tested in isolation. Their functional screens and persistent storage remain to be built:

- Save the player's own gaming profile and availability.
- Record and update teammate details provided with their consent.
- Find teammates by server, needed role, shared play time, and voice-chat preference.
- Prepare a proposal using the actual shared time and preview it before sharing through an existing messaging app.
- Maintain a private avoid list, with a way to restore a teammate to future searches.

The local version searches the user's own teammate directory, not a live player network. Any future sample profiles must be clearly identified as examples and kept separate from user-entered contacts.

Creating or sharing a proposal is not evidence of delivery, acceptance, or a confirmed session. Players must confirm the exact date and arrangements outside GameLink. The app will not verify game-account ownership, skill, or current online status.

Out of scope: account registration, cloud sync, Firebase, live stranger matching, in-app chat, payments, leaderboards, game-history scraping, game-client automation, and AI recommendations. Do not collect game passwords or access tokens.

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

Every Use Case has a typed error enum with English recovery guidance, success tests, and failure tests. `WeeklyPlayWindowTests` separately covers time validation and overlap boundaries.

The first persistence implementation is planned as an atomic JSON store in the app's private Application Support directory. Failed writes must preserve previous data; unreadable files must not be silently replaced with an empty directory of players.

Current source folders:

- `GameLink/GameLink/App`: application entry point.
- `GameLink/GameLink/Presentation`: informational home screen only.
- `GameLink/GameLink/Domain`: immutable validated profiles and play windows, squad models, and the notebook repository contract.
- `GameLink/GameLink/Application`: the five business Use Cases.
- `GameLink/GameLinkTests`: independent Swift Testing suites and a test-only in-memory notebook.

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

Production disk-write atomicity, corrupt-file recovery, and restart persistence are not established by the in-memory tests. They belong to Stage 3.

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

Tests use a fresh, isolated in-memory repository for each scenario. They do not access live accounts, send messages, modify the app's saved data, or depend on test execution order. Failure injection happens before test-store mutation. Business testing does not yet constitute UI or persistence validation.

## Remaining assessment work

- Connect the business layer to production local storage, ViewModels, and at least four functional SwiftUI screens.
- Present the existing domain errors with useful recovery actions in those screens.
- Extend business tests with real persistence and complete workflow validation; the minimum Use Case and unit-test counts are already represented in code.
- Produce a one-page human-system architecture diagram in PDF or PNG, showing layers, responsibility boundaries, and the main data flow.
- Write a 600-800-word English reflective report, grounded in actual design and validation evidence, and export it as PDF.
- Validate the working app in Xcode and package the project for submission.
- Provide a Git repository link only after the owner authorizes commits and a push.

Next development stage: production local persistence, validated decoding, atomic writes, and restart/failure tests. No UI feature is considered complete merely because its business logic exists.

## Foundation validation

On September 8, 2026, the simulator build and launch passed with Xcode 26.6 on an iPhone 17 Pro simulator running iOS 26.5. Swift formatting checks passed, and no Chinese characters were found in project source, resources, or documentation, excluding Git internals and local Xcode user state.

Light and dark appearance were visually checked. The largest Dynamic Type size wraps the text, but complete scrolling remains unverified because automated gestures did not move the simulator content. Small-phone, iPad, physical-device, and spoken VoiceOver checks remain pending. This describes the unchanged informational screen, not future functional screens.

Stage 2 adds 58 test methods, expanded into 75 test instances through parameterized cases. Two complete simulator runs passed with no failures or skipped tests. A temporary mutation from "at least 30 minutes" to "more than 30 minutes" correctly failed the boundary test; the correct rule was restored before the final passing run. Swift formatting and the English-only source check also passed. Results validate the domain layer and test-repository behavior, not real disk persistence or a completed MVP.

## Git

Keep all work local. Do not stage, commit, or push without explicit owner approval. Do not restore the previous project's Git history or manufacture retrospective commits.

The intended remote is [Junhao-Fred/GameLink](https://github.com/Junhao-Fred/GameLink). If publishing is authorized later, verify the active account is `Junhao-Fred` and verify the destination before pushing. The assessment's version-control requirement remains pending while commits are paused.
