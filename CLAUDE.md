# Veera

Personal-use gamified iOS habit tracker. SwiftUI + SwiftData, **iOS 26+**, iPhone 14 Plus target. Liquid Glass and other WWDC25 APIs are used directly — no availability guards needed.

This is a **personal project** — one user (me), no App Store distribution, free signing, sideload via SideStore later. Cost target ₹0. Bundle id `com.kv.veera`.

Also a portfolio piece for DevSecOps work: SwiftLint, semgrep, gitleaks, dependabot, OSLog observability, biometric gate, and a `THREAT_MODEL.md` are all planned.

_Last updated: 2026-06-09._

## Current state

Build + SwiftLint --strict both green as of 2026-06-09 after Phases 5–10 (Widgets → HealthKit auto-XP → calendar heatmap + radar → Vows → EventKit one-way mirror → performance + meaningful haptics). 33 unit tests in the suite (Phases 5–10 added no tests; deferred to next sweep).

Implemented since Phase 4:
- **Widgets — parked.** Phase 5's widget extension was removed because Apple's free signing flow doesn't support App Group entitlements reliably, so the widget couldn't read the shared SwiftData store. Re-enable when a paid Developer Program is in place — at that point, re-add the Widget Extension target, restore the staged widget source files (`VeeraWidgets/*` is in git history), re-introduce `CompleteQuestIntent`, and re-wire `WidgetCenter.shared.reloadAllTimelines()` in HomeView's completion paths.
- **Shared SwiftData store** (`Services/SharedPersistence.swift`): kept. Tries the App Group container at `group.com.kv.veera.shared` then falls back to the default location, so the main app works either way. The widget would have used this when paid signing makes App Groups available.
- **HealthKit auto-XP** (`Services/HealthKitImporter.swift`): steps→STR, sleep→VIT, mindful→DSC, workouts→STR+VIT. Idempotent via `HealthImportLedger` keyed on `(source, calendar-day)`. Per-source toggles in Settings; permission prompted on first toggle-on. Runs on app foreground via `veeraApp`'s `.task`.
- **Vows** (`Models/Vow.swift`, `VowCheckIn.swift`; `Views/Vows/VowsView.swift`, `AddVowView.swift`): "Sacred Vows" section shown on Home above the quest list. Title + body + duration (7/30/60/90 days). Daily Yes/No on the card; "No" raises a full-screen broken overlay that stamps a red seal on the card for the remaining days. No XP/streak interaction — vows sit outside the gamified loop.
- **EventKit one-way mirror** (`Services/EventKitExporter.swift`): pushes Habit→`EKReminder`, TaskItem→`EKEvent`, Reminder→`EKReminder` into a dedicated "Veera" calendar/list. Idempotent via `eventKitIdentifier` stored on each model. Settings exposes two toggles + a "Re-sync All" button. Deletes in Veera remove the mirror; deletes outside Veera don't affect Veera.
- **Stats tab additions** (`Views/Stats/StatsView.swift`): 365-day XP `Canvas` heatmap (gold opacity per day, max-normalised) + 5-vertex stat radar polygon, both rendered with `Canvas` + trig. Lazy-rendered: charts wait for the tab's first `.onAppear`. `StatsAggregator.dailyXPMap(forYear:)` + `statValues(in:)` feed them.
- **Heraldic primitives**: `Theme/Signet.swift` (shared rotated-square + serif V), `Theme/HeraldicDividers.swift` (`HeraldicDivider` + `HeraldicBanner`). Stats sections separated by `HeraldicDivider`.
- **Haptics** (`Services/HapticEngine.swift`): single `@MainActor` singleton wrapping CoreHaptics + UIFeedbackGenerator. API: `.quest(.complete/.uncomplete)`, `.levelUp()` (3 ascending taps), `.rankUp()` (5 taps with rising sharpness), `.vowSworn()` (heavy thud + low rumble), `.vowBroken()` (two sharp cracks), `.tabChange()`. `RoyalButtonStyle` no longer haptics on press — taps are silent unless the action means something. Toggleable in Settings.
- **Performance**: HomeView's completions `@Query` bounded to today via a `Predicate`. Stats charts gated behind `hasAppeared`. Larger `PlayerStore` `@Observable` refactor parked for the next sweep — current cost is acceptable.
- **DevSecOps**: `.swiftlint.yml` clean under `--strict` across 49 source files. `.github/workflows/ci.yml` still builds + tests + lints + runs Semgrep.

Implemented:
- **App shell**: onboarding (first launch only, replayable from Settings) → per-launch `WelcomeBackView` splash → TabView. No in-app biometric gate — the device passcode is the trust boundary (see `THREAT_MODEL.md` M1).
- **Onboarding** (`Views/Onboarding/OnboardingView.swift`): four pages — welcome, five stats, rank ladder, difficulty choice — gated by `@AppStorage("veera.onboardingCompleted")`. Replay button in Settings.
- **Welcome-back greeting** (`Views/Onboarding/WelcomeBackView.swift`): ~1.4s fade-in/out splash with the player's name. `@State` in `ContentView` resets only on cold launch, so warm restarts skip it.
- **Home**: NavigationStack-wrapped. Player card with `LevelBadge`, stat row, daily totals, today's quest checklist. Habit row has two tap targets — the leading checkmark toggles (tap done → undo today's completion + revoke XP), the rest of the row navigates to `HabitDetailView`. On-appear missed-day check via `.task(id: player?.id)`. Full-screen `LevelUpOverlay` celebration when a completion crosses a level boundary.
- **Quests**: glass-card sections for habits/tasks/reminders; three prominent action buttons (HABIT / TASK / BELL) at the top; habit cards push `HabitDetailView` on tap; context menu adds Edit + Archive/Delete/Pause; sheets present `AddHabitView` / `AddTaskView` / `AddReminderView` in both add and edit modes via an optional `existing:` initializer.
- **Habit detail** (`Views/Quests/HabitDetailView.swift`): header, 7-day heatmap (gold-filled = done, outlined = missed, dimmed-gold = today still open), stats row (total / longest-ever / current / last), schedule card (cadence + reminder), recent completions (last 14), Edit + Archive actions. Habit history helpers (`completions(in:)`, `completionMap(days:endingOn:)`, `longestStreakEver`, `totalCompletions`, `lastCompletedAt`) live in an extension on `Habit`.
- **Stats tab** (`Views/Stats/StatsView.swift`): Swift-Charts weekly XP bar chart (last 8 weeks), per-stat column chart, longest-streak-per-category list, and a horizontal rank-up timeline. Sections separated by `HeraldicDivider`. Aggregation lives in `Services/StatsAggregator.swift` (pure functions consumed by the view; `@MainActor` `recordRankIfNeeded` persists `RankAchievement` records as the player crosses rank boundaries).
- **Heraldic primitives** (`Theme/Signet.swift`, `Theme/HeraldicDividers.swift`): shared `Signet` view (gold rotated-square with centered serif V) and `HeraldicDivider` / `HeraldicBanner` shapes for cross-view reuse. Launch screen wiring is a manual Xcode UI step (`INFOPLIST_KEY_UILaunchScreen_ImageName`) — code is ready when you are.
- **OSLog**: new `quest_actions` category in `AppLogger`. Instrumented events: habit complete/undo, task complete/undo, hard-mode miss penalty, habit archive, task delete, reminder pause/scheduled/cancelled. Names + reminder content marked `.private`; categories + XP + counts marked `.public`.
- **Settings**: glass-card layout for player summary, name editor, XP progress, penalty-mode picker with clearer copy, manual missed-day check, notification permission status, replay-onboarding row, and a destructive "Reset Local Data" path.
- **App icon** (`Assets.xcassets/AppIcon.appiconset/`): generated programmatically by `tools/iconmaker.swift` (CoreGraphics + CoreText). Three variants: standard (gold V on warm-black signet), dark (same), tinted (white V on pure black so iOS tint mode re-colors cleanly). Re-run with `swift /tmp/iconmaker.swift` after edits.
- **Services**:
  - `PersistenceController` bootstraps the singleton `Player` on first launch. Starts empty — no seed habits. Exposes `resetLocalData(in:)` used by Settings.
  - `XPEngine` handles level, rank progress, stat level, XP awards, and hard-mode miss penalties.
  - `StreakEngine` records activity, detects missed habits, applies missed-day resets/penalties; penalty deduplicated per calendar day via `Player.lastMissCheckedDate`.
  - `NotificationService` requests permission on first reminder save (not at app launch) and schedules/cancels reminder notifications. **M4 mitigation**: when `@AppStorage("veera.hideLockScreenContent")` is on (default), schedules a generic title (`"Veera"`) and body (`"A quest awaits."`) with the real reminder content in `userInfo`. Toggling the Settings flag re-schedules all active reminders via `rescheduleAll(in:)`. A `NotificationDelegate` singleton (wired in `veeraApp.init`) handles foreground delivery.
  - `AppLogger` defines OSLog categories for persistence/progression/notifications.
- **DevSecOps**: `.swiftlint.yml` clean under `--strict` across all source files; `.github/workflows/ci.yml` runs build + test + SwiftLint + Semgrep on push; `.semgrep.yml` extends `p/swift` + `p/security-audit`; `.github/dependabot.yml` watches SPM + Actions weekly; `.gitleaks.toml` + `.pre-commit-config.yaml` run gitleaks and hygiene checks on every commit (`pre-commit install` to enable — see `docs/devsecops.md`); `THREAT_MODEL.md` at repo root carries an explicit revision history.
- **Tests**:
  - `ProgressionTests` covers level bands, rank boundaries, habit + task XP awards, and hard-mode penalty floor.
  - `StreakEngineTests` covers first activity, consecutive/skipped days, missed-habit detection, same-day penalty idempotency, and the pure `computeStreak` rebuild helper.
  - `CadenceCodableTests` covers `.daily` / `.weekly` / `.customDays` JSON round-trips, empty-set decoding, and custom-weekday `isDue(on:)` matching.
  - `HabitDetailDataTests` covers the date-range completions query, the 7-day completion-map boundary (today/yesterday/6-days-ago included, 8-days-ago excluded), and `longestStreakEver` consecutive-day walking.
  - `StatsAggregatorTests` covers weekly-XP bucketing (count, per-week sums, out-of-window exclusion), per-stat columns, longest-streak-per-category aggregation, rank-timeline sorting, and rank-recording deduplication.

Verified:
- `xcodebuild -project veera.xcodeproj -scheme veera -configuration Debug -destination generic/platform=iOS -derivedDataPath /private/tmp/veera-derived CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project veera.xcodeproj -scheme veera -configuration Debug -destination generic/platform=iOS -derivedDataPath /private/tmp/veera-derived CODE_SIGNING_ALLOWED=NO build-for-testing`

Both succeeded. Local simulator execution was not verified in Codex because CoreSimulator was unavailable in the tool environment.

## Goals

- Gamified habit tracker: Quests, XP, Levels, Ranks. Final rank to chase is **Maaveeran** (Tamil for "great warrior").
- Soft + hard penalty modes, togglable in Settings.
- Five stats: STR, INT, VIT, DSC, WIL.
- Home shows: player card with LevelBadge, 5-stat row, today's quest list with check rows, daily totals (streak / XP today / pending).

## Aesthetic & tone

- Black background, royal gold `#C9A24B`, red `#B83838`.
- Serif numerals (level, XP, stats). Heraldic icons.
- Language is **"light regal"**: Quests, Level, Rank. *Not* Decrees/Dominion/etc.

## Conventions

- **Colors & typography**: always go through `Theme.*` (see `Theme/Colors.swift`, `Theme/Typography.swift`). Never hardcode color literals or system fonts in views.
- **Numerals**: use the serif numeral style from `Theme/Typography.swift` for any number the user sees (level, XP, stat values, streak counts).
- **SwiftData models**: do **not** give enums raw values inside `@Model` classes — SwiftData persistence handles raw enums poorly. Store a `*Raw: String` (or Int) property and expose a computed enum property. Example:
  ```swift
  @Model final class Habit {
      var categoryRaw: String
      var category: HabitCategory {
          get { HabitCategory(rawValue: categoryRaw) ?? .discipline }
          set { categoryRaw = newValue.rawValue }
      }
  }
  ```
- **Naming**: the task model is `TaskItem`, not `Task` — `Task` collides with Swift concurrency's `Task` type and produces confusing errors. Apply the same caution to any other name that shadows a stdlib/Foundation/Swift Concurrency symbol.
- **Value-type enums**: declare them `nonisolated` (especially `Codable` ones used by `@Model` properties). The project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so unannotated enums get inferred as `@MainActor` and their `Codable` conformance becomes MainActor-isolated — which `JSONEncoder`/`JSONDecoder` (nonisolated) can't use. Pure data has no business being MainActor-bound; mark it `nonisolated`.
- **Associated-value Codable enums**: if synthesized `Codable` still produces MainActor-isolated warnings, write explicit `nonisolated init(from:)` and `nonisolated encode(to:)`. `Cadence` does this now because it is encoded into `Habit.cadenceData`.
- **Concurrency**: prefer `async`/`await`. Avoid Combine.
- **Style**: 4-space indent, PascalCase types, camelCase members, `@State private var` for view-local state, `let` for constants. Strong types, no force-unwraps.
- **Comments**: only when the *why* is non-obvious. Don't narrate what the code does.
- **Haptics**: always via `HapticEngine.shared.<verb>()`. Never call `UIFeedbackGenerator` or `CHHaptic` from views directly. Haptics are reserved for meaningful events (completion, level-up, rank-up, vow rites, tab change) — they're silent on ordinary button presses on purpose.

## Folder structure

```
veera/veera/
  App/          // veeraApp.swift, ContentView.swift — app entry, root nav
  Models/       // @Model SwiftData types + Enums.swift
  Services/     // PersistenceController, XPEngine, StreakEngine, NotificationService
  Theme/        // Colors, Typography, HeraldicSymbol (LevelBadge etc.)
  Views/        // Feature-grouped subfolders: Home/, Quests/, Settings/, ...
  Assets.xcassets
veera/veeraTests/        // Swift Testing unit tests
veera/veeraUITests/      // XCUIAutomation UI tests
```

Where new files go:
- New `@Model` type → `Models/`. New enum used by models → `Enums.swift` (or its own file if large).
- New domain service (engine, notification, sync) → `Services/`.
- New visual primitive reused across views → `Theme/`.
- New feature screen → `Views/<Feature>/`.

## Build & verify

- Use the `BuildProject` MCP command from `xcode-tools` to build.
- For quick per-file checks while editing, use `XcodeRefreshCodeIssuesInFile`.
- If `xcode-tools` is unavailable, generic iOS CLI build works:
  ```sh
  xcodebuild -project veera.xcodeproj -scheme veera -configuration Debug -destination generic/platform=iOS -derivedDataPath /private/tmp/veera-derived CODE_SIGNING_ALLOWED=NO build
  ```
- Tests: Swift Testing (`@Test`) for units in `veeraTests/`, XCUIAutomation for UI in `veeraUITests/`.

## Next work

Top of the backlog (in priority order):
1. **App Blocking** via FamilyControls + ManagedSettings + DeviceActivity, paired with a Focus Mode timer so a "deep work" quest can actually shut other apps out. Evaluate FamilyControls feasibility under free signing first.
2. **Tirukkural daily verse** — surface a couplet on Home each morning, rotated through the 1330 kurals. Tamil text + transliteration + short prose translation. Tap → expand for commentary. Source: bundle the public-domain Drew/Pope translation as JSON.
3. **Sigil generator** — procedural emblem unique to the player, derived from name + birth date. Used in the launch screen, top of Settings, and as an avatar in the welcome-back splash.
4. **Year-in-review screen** — generated each January 1st (and on-demand). Total XP, longest streak, ranks gained, most-completed habit, longest-kept vow. Shareable as an image.

Carry-overs from earlier sweeps:
- Phases 5–9 require Xcode UI steps to fully activate:
  - **Widget Extension target** (Phase 5) — create `VeeraWidgets` extension, add the `VeeraWidgets/*.swift` files to it, App Group `group.com.kv.veera.shared` on both targets.
  - **HealthKit capability** + `NSHealthShareUsageDescription` (Phase 6).
  - **NSCalendarsUsageDescription** + **NSRemindersUsageDescription** (Phase 9).
  - **App display name** → `Veera` (`INFOPLIST_KEY_CFBundleDisplayName`).
  - **Launch screen wiring** — `Theme/Signet.swift` is ready; set `INFOPLIST_KEY_UILaunchScreen_ImageName = LaunchSignet` after exporting a 1024 PNG.
- Tests for Phases 5–10 (widget snapshot, HealthKit ledger idempotency, Vow daily rules, EventKit identifier round-trips, haptic-toggle gating) parked for the next sweep.
- `PlayerStore` `@Observable` cache to stop @Query refetches across views.

## Out of scope (for now)

- CloudKit / iCloud sync — not enabled. Local-only via SwiftData.
- App Store metadata, screenshots, marketing copy.
- Multi-user / accounts.

## Working rules for this repo
- Touch ONLY the files named in the task. Don't read or refactor the rest of the repo.
- One concern per task. Stop when it builds — don't gold-plate or add extras.
- SwiftLint strict mode and a clean build must pass.
- When done: list changed files, one line each. No full-diff recap.
- Match the existing aesthetic (black/gold/oxblood, serif numerals) and reuse existing
  helpers — don't reinvent XP/rank/stat logic.