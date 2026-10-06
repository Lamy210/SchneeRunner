# Productivity Timers and Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add restart-safe countdown timers, Pomodoro sessions, recurring reminders with snooze, bounded history, macOS local notifications, management UI, and optional SchneeRunner character reactions.

**Architecture:** Keep all deterministic time/state/recurrence rules in `SchneeRunnerCore`; keep run-loop timers, `UserNotifications`, AppKit UI, filesystem writes, and application lifecycle in `SchneeRunnerApp`. Running countdowns and Pomodoro phases are deadline-authoritative; the in-process timer only refreshes UI, while stable local-notification identifiers and persisted snapshots make restart/sleep reconciliation idempotent.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, Foundation, UserNotifications, XCTest, existing `CommonRunLoopTimerScheduler`, existing `CharacterStateTriggerEngine`.

**Spec:** `docs/superpowers/specs/2026-10-07-productivity-timers-reminders-design.md`

## Global Constraints

- Minimum platform remains macOS 14.
- No third-party package is added for timers, recurrence, persistence, notifications, or UI.
- `SchneeRunnerCore` must not own AppKit, `Timer`, `UNUserNotificationCenter`, application lifecycle, or macOS-only APIs.
- Deadline values, not periodic tick counts, are authoritative for running countdowns and Pomodoro phases.
- Multiple countdown timers are allowed; only one Pomodoro session may be active.
- Countdown presets are 5, 10, 15, 25, 30, and 60 minutes; arbitrary positive durations are also supported.
- Pomodoro defaults are 25 minute focus, 5 minute short break, 15 minute long break, and a long break after 4 completed focus phases; auto-start defaults to off.
- Reminder recurrence supports one-shot, daily, and selected weekdays; snooze choices are 5, 10, 15, 30, and 60 minutes.
- Productivity history is bounded to the newest 500 entries.
- Productivity character reactions are enabled by default and globally toggleable.
- Productivity uses one aggregated `.event` priority trigger; `.manual` remains authoritative over it.
- Pull requests remain short-lived `feat/*` branches, with tests, SwiftFormat, SwiftLint, required CI, review-conversation resolution, and squash merge before dependent work rebases from `main`.

## Review Focus

- **Wall-clock jumps while a countdown is active:** remaining time must be recomputed from the persisted deadline and never from accumulated ticks; Task 1 pins this with deterministic `remaining(at:)` tests.
- **DST or missing local times for recurring reminders:** `ReminderSchedule.nextOccurrence(after:calendar:)` must use `Calendar.nextDate`-style matching semantics and return the next valid wall-clock occurrence; Task 6 covers spring-forward and weekday recurrence.
- **Repeated startup reconciliation:** an overdue timer or Pomodoro phase must complete exactly once and must not create duplicate history; Tasks 2 and 5 test idempotent reconciliation.
- **Foreign pending notifications:** synchronization must only add/remove identifiers owned by SchneeRunner productivity prefixes; Tasks 3 and 7 verify unrelated requests are preserved.
- **Corrupt or unsupported persisted state:** load must fail explicitly without replacing the source file; Task 2 verifies malformed JSON and unsupported schema versions remain untouched.

---

## Delivery Sequence

Each task below is independently reviewable. Tasks 1-3 establish the countdown foundation; Tasks 4-5 ship Pomodoro; Tasks 6-7 ship reminders; Tasks 8-10 finish history/management UI/reactions/integration. After each merged task, start the next branch from the updated `main` rather than keeping one long-lived feature branch.

### Task 1: Core Countdown Domain

**Files:**
- Create: `Sources/SchneeRunnerCore/ProductivityCountdownTimer.swift`
- Create: `Tests/SchneeRunnerCoreTests/ProductivityCountdownTimerTests.swift`

**Interfaces:**
- Produces `public enum ProductivityTimerState: String, Codable, Equatable, Sendable { case running, paused, completed, cancelled }`.
- Produces `public struct ProductivityCountdownTimer: Codable, Equatable, Sendable` with `id`, `title`, `originalDuration`, `startedAt`, `deadline`, `pausedRemaining`, `state`, and `completedAt`.
- Produces `public init(id:title:duration:startedAt:) throws` for a running timer.
- Produces `public func remaining(at now: Date) -> TimeInterval`.
- Produces `public func pausing(at now: Date) throws -> ProductivityCountdownTimer`.
- Produces `public func resuming(at now: Date) throws -> ProductivityCountdownTimer`.
- Produces `public func cancelling() -> ProductivityCountdownTimer`.
- Produces `public func reconciling(at now: Date) -> ProductivityCountdownTimer`.
- Later tasks consume the model without owning tick-based elapsed state.

- [ ] **Step 1: Write failing Core tests**

Add tests named:

```swift
func testRunningTimerDerivesRemainingFromDeadline()
func testPauseStoresRemainingAndClearsDeadline() throws
func testResumeCreatesFreshDeadlineFromPausedRemaining() throws
func testReconcileCompletesOverdueTimerExactlyOnce()
func testRejectsNonPositiveDuration()
func testClockJumpUsesDeadlineRatherThanTickCount()
```

Assertions must pin a 25-minute timer started at `2026-10-07T00:00:00Z`, expect a deadline 1,500 seconds later, and verify pause/resume against explicit `Date` values.

- [ ] **Step 2: Run the new test file and confirm RED**

Run: `swift test --filter ProductivityCountdownTimerTests`

Expected: FAIL because `ProductivityCountdownTimer` and `ProductivityTimerState` do not exist.

- [ ] **Step 3: Implement the countdown value type**

Implement the interfaces above in `ProductivityCountdownTimer.swift`. Keep validation deterministic and typed; do not import AppKit or create a `Timer`.

- [ ] **Step 4: Run Core tests and quality checks**

Run:

```bash
swift test --filter ProductivityCountdownTimerTests
swiftformat --lint .
swiftlint lint --strict
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SchneeRunnerCore/ProductivityCountdownTimer.swift Tests/SchneeRunnerCoreTests/ProductivityCountdownTimerTests.swift
git commit -m "feat: add countdown timer domain"
```

### Task 2: Productivity Snapshot Persistence and Restart Reconciliation

**Files:**
- Create: `Sources/SchneeRunnerCore/ProductivitySnapshot.swift`
- Create: `Sources/SchneeRunnerApp/ProductivityStateStore.swift`
- Create: `Tests/SchneeRunnerCoreTests/ProductivitySnapshotTests.swift`
- Create: `Tests/SchneeRunnerAppTests/ProductivityStateStoreTests.swift`

**Interfaces:**
- Consumes `ProductivityCountdownTimer` from Task 1.
- Produces `public struct ProductivitySnapshot: Codable, Equatable, Sendable` with `schemaVersion`, `timers`, optional Pomodoro state for later schema-compatible extension, and reminders collection for later schema-compatible extension.
- Produces `public static let currentSchemaVersion = 1`.
- Produces `public func reconciling(at now: Date) -> ProductivitySnapshot` that is idempotent for already-completed timers.
- Produces `@MainActor final class ProductivityStateStore` with `init(baseDirectory:fileManager:)`, `func load() throws -> ProductivitySnapshot`, and `func save(_ snapshot: ProductivitySnapshot) throws`.
- Store path is `<baseDirectory>/SchneeRunner/Productivity/state.json` in production, with injectable test directories.

- [ ] **Step 1: Write failing snapshot/reconciliation tests**

Add tests for current-version decoding, unsupported-version rejection, one overdue timer completing once, and a second reconciliation producing the identical snapshot.

- [ ] **Step 2: Write failing persistence-boundary tests**

Add tests that save/load a valid snapshot, reject malformed JSON without rewriting it, reject unsupported schema without rewriting it, and leave the previous valid file readable when staging/replacement fails.

- [ ] **Step 3: Run focused tests and confirm RED**

Run:

```bash
swift test --filter ProductivitySnapshotTests
swift test --filter ProductivityStateStoreTests
```

Expected: FAIL because snapshot/store types do not exist.

- [ ] **Step 4: Implement versioned snapshot and atomic store**

Use a staged sibling file followed by an atomic move/replace. Validate decoded schema before exposing it; do not silently reset malformed/unsupported files.

- [ ] **Step 5: Verify focused tests and quality gates**

Run:

```bash
swift test --filter ProductivitySnapshotTests
swift test --filter ProductivityStateStoreTests
swiftformat --lint .
swiftlint lint --strict
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SchneeRunnerCore/ProductivitySnapshot.swift Sources/SchneeRunnerApp/ProductivityStateStore.swift Tests/SchneeRunnerCoreTests/ProductivitySnapshotTests.swift Tests/SchneeRunnerAppTests/ProductivityStateStoreTests.swift
git commit -m "feat: persist productivity state"
```

### Task 3: Countdown Runtime and Notification Scheduling

**Files:**
- Create: `Sources/SchneeRunnerApp/ProductivityNotificationScheduler.swift`
- Create: `Sources/SchneeRunnerApp/TimerCoordinator.swift`
- Create: `Tests/SchneeRunnerAppTests/ProductivityNotificationSchedulerTests.swift`
- Create: `Tests/SchneeRunnerAppTests/TimerCoordinatorTests.swift`

**Interfaces:**
- Consumes `ProductivityCountdownTimer`, `ProductivitySnapshot`, and `ProductivityStateStore`.
- Produces protocol `ProductivityNotificationScheduling` so coordinator tests do not require the real notification center.
- Produces `@MainActor final class ProductivityNotificationScheduler: ProductivityNotificationScheduling` backed by `UNUserNotificationCenter`.
- Produces `static func timerIdentifier(for id: UUID) -> String` returning `schneerunner.timer.<uuid>`.
- Produces `@MainActor final class TimerCoordinator` with `onChange: (([ProductivityCountdownTimer]) -> Void)?`, `start(title:duration:now:)`, `pause(id:now:)`, `resume(id:now:)`, `cancel(id:)`, `reconcile(now:)`, `startRefreshing()`, and `stopRefreshing()`.
- Refresh uses `CommonRunLoopTimerScheduler`; completion authority remains `deadline`.

- [ ] **Step 1: Write failing scheduler tests**

Test stable lowercase UUID identifiers, replacement of the same logical timer request, preservation of unrelated pending notification identifiers, and denied authorization as a degraded-notification result rather than a domain failure.

- [ ] **Step 2: Write failing coordinator tests**

Test multiple concurrent timers, pause/resume persistence, one overdue completion, notification cancel on cancellation, and refresh callbacks while `.eventTracking` run-loop mode is active.

- [ ] **Step 3: Run focused tests and confirm RED**

Run:

```bash
swift test --filter ProductivityNotificationSchedulerTests
swift test --filter TimerCoordinatorTests
```

Expected: FAIL because the scheduler/coordinator interfaces do not exist.

- [ ] **Step 4: Implement notification adapter and timer coordinator**

Schedule completion with `UNTimeIntervalNotificationTrigger` derived from the authoritative deadline. Keep permission/scheduling errors separately reportable from timer-domain persistence.

- [ ] **Step 5: Verify tests and quality gates**

Run the two focused suites plus SwiftFormat/SwiftLint; expected PASS.

- [ ] **Step 6: Commit**

Commit as `feat: add countdown runtime and notifications`.

### Task 4: Countdown Status-Menu UI

**Files:**
- Create: `Sources/SchneeRunnerApp/TimerMenuController.swift`
- Create: `Tests/SchneeRunnerAppTests/TimerMenuControllerTests.swift`
- Modify: `Sources/SchneeRunnerApp/StatusMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/AppDelegate.swift`
- Modify: `Tests/SchneeRunnerAppTests/StatusMenuControllerTests.swift`

**Interfaces:**
- Consumes `TimerCoordinator` observable state.
- Produces `@MainActor final class TimerMenuController` with callbacks for creating preset/custom timers and pause/resume/cancel actions.
- `StatusMenuController` owns one Timer submenu and forwards callbacks; it does not own timer state or persistence.
- `AppDelegate` wires menu callbacks to `TimerCoordinator` and starts/stops coordinator refresh with app lifecycle.

- [ ] **Step 1: Write failing menu tests**

Pin preset labels `5 min`, `10 min`, `15 min`, `25 min`, `30 min`, `60 min`, active timer rows, and callback dispatch for pause/resume/cancel.

- [ ] **Step 2: Run menu tests and confirm RED**

Run: `swift test --filter TimerMenuControllerTests`

- [ ] **Step 3: Implement the narrow submenu controller and AppDelegate wiring**

Do not place persistence or deadline calculations in the menu controller.

- [ ] **Step 4: Run menu/App tests plus quality gates**

Expected: PASS.

- [ ] **Step 5: Commit**

Commit as `feat: add countdown menu controls`.

### Task 5: Pomodoro Domain, Runtime, and Recovery

**Files:**
- Create: `Sources/SchneeRunnerCore/PomodoroSession.swift`
- Create: `Sources/SchneeRunnerApp/PomodoroCoordinator.swift`
- Create: `Sources/SchneeRunnerApp/PomodoroMenuController.swift`
- Create: `Tests/SchneeRunnerCoreTests/PomodoroSessionTests.swift`
- Create: `Tests/SchneeRunnerAppTests/PomodoroCoordinatorTests.swift`
- Create: `Tests/SchneeRunnerAppTests/PomodoroMenuControllerTests.swift`
- Modify: `Sources/SchneeRunnerCore/ProductivitySnapshot.swift`
- Modify: `Sources/SchneeRunnerApp/StatusMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/AppDelegate.swift`

**Interfaces:**
- Produces `PomodoroConfiguration` with defaults 25m/5m/15m/4/off.
- Produces `PomodoroPhase { focus, shortBreak, longBreak }` and `PomodoroSession` with authoritative `phaseDeadline`/`pausedRemaining`.
- Produces deterministic `advancing(at:)` behavior: every fourth completed focus enters long break; otherwise focus alternates with short break.
- Produces one-active-session `PomodoroCoordinator` with start/pause/resume/stop/reconcile.
- Notification identifier is `schneerunner.pomodoro.<session-uuid>.<phase>`.

- [ ] **Step 1: Write failing Core tests**

Cover defaults, normal focus→short break, fourth focus→long break, pause/resume, auto-start off, auto-start on, and repeated overdue reconciliation not double-advancing.

- [ ] **Step 2: Write failing App tests**

Cover single-session enforcement, persistence after each transition, phase notification replacement, startup recovery, and menu callbacks.

- [ ] **Step 3: Run focused tests and confirm RED**

Run `swift test --filter Pomodoro` and confirm missing interfaces fail.

- [ ] **Step 4: Implement Core session, coordinator, notifications, and submenu**

Use the existing notification abstraction; do not duplicate `UNUserNotificationCenter` logic.

- [ ] **Step 5: Verify Pomodoro suites and quality gates**

Expected: PASS.

- [ ] **Step 6: Commit**

Commit as `feat: add Pomodoro sessions`.

### Task 6: Reminder Recurrence Domain

**Files:**
- Create: `Sources/SchneeRunnerCore/ReminderSchedule.swift`
- Create: `Sources/SchneeRunnerCore/ProductivityReminder.swift`
- Create: `Tests/SchneeRunnerCoreTests/ReminderScheduleTests.swift`
- Create: `Tests/SchneeRunnerCoreTests/ProductivityReminderTests.swift`
- Modify: `Sources/SchneeRunnerCore/ProductivitySnapshot.swift`

**Interfaces:**
- Produces `public enum Weekday: Int, Codable, CaseIterable, Sendable` matching Calendar weekday values.
- Produces `public enum ReminderSchedule: Codable, Equatable, Sendable { case once(Date), daily(hour:Int, minute:Int), weekdays(Set<Weekday>, hour:Int, minute:Int) }`.
- Produces `public func nextOccurrence(after now: Date, calendar: Calendar) -> Date?`.
- Produces `public struct ProductivityReminder` with `id`, `title`, optional `body`, `enabled`, `schedule`, `createdAt`, `updatedAt`.
- Invalid hours/minutes and empty weekday sets are rejected by construction/validation.

- [ ] **Step 1: Write failing recurrence tests**

Cover future one-shot, expired one-shot returning nil, daily same-day/next-day boundaries, selected weekdays, DST spring-forward missing time, and disabled reminder behavior.

- [ ] **Step 2: Run Core reminder tests and confirm RED**

Run: `swift test --filter Reminder`

- [ ] **Step 3: Implement recurrence with Calendar semantics**

Use `Calendar` matching APIs rather than manual second arithmetic for wall-clock recurrence.

- [ ] **Step 4: Verify reminder tests and Core quality**

Expected: PASS.

- [ ] **Step 5: Commit**

Commit as `feat: add reminder recurrence domain`.

### Task 7: Reminder Notification Reconciliation and Snooze

**Files:**
- Create: `Sources/SchneeRunnerCore/ReminderSnooze.swift`
- Create: `Sources/SchneeRunnerApp/ReminderCoordinator.swift`
- Create: `Tests/SchneeRunnerCoreTests/ReminderSnoozeTests.swift`
- Create: `Tests/SchneeRunnerAppTests/ReminderCoordinatorTests.swift`
- Modify: `Sources/SchneeRunnerApp/ProductivityNotificationScheduler.swift`

**Interfaces:**
- Produces `ReminderSnooze` as a temporary one-shot occurrence retaining the parent reminder ID without altering its recurrence schedule.
- `ReminderCoordinator` exposes create/update/delete/setEnabled/snooze/reconcile.
- Reminder identifier prefix is `schneerunner.reminder.` and snooze identifier is `schneerunner.snooze.<uuid>`.
- Reconciliation computes desired pending requests from the persisted reminders/snoozes, then only removes obsolete requests under known productivity prefixes.

- [ ] **Step 1: Write failing snooze tests**

Pin 5/10/15/30/60-minute options and assert the parent recurrence is unchanged.

- [ ] **Step 2: Write failing reconciliation tests**

Cover add, replace, disable/remove, repeated idempotent reconciliation, app-restart reconstruction, and preservation of a foreign notification ID such as `com.example.foreign`.

- [ ] **Step 3: Run focused tests and confirm RED**

Run `swift test --filter ReminderCoordinatorTests` and `swift test --filter ReminderSnoozeTests`.

- [ ] **Step 4: Implement coordinator and synchronization**

Reuse the Task 3 scheduler abstraction; no second notification-center wrapper.

- [ ] **Step 5: Verify tests and quality gates**

Expected: PASS.

- [ ] **Step 6: Commit**

Commit as `feat: schedule reminders and snooze`.

### Task 8: Bounded Productivity History

**Files:**
- Create: `Sources/SchneeRunnerCore/ProductivityHistory.swift`
- Create: `Sources/SchneeRunnerApp/ProductivityHistoryStore.swift`
- Create: `Tests/SchneeRunnerCoreTests/ProductivityHistoryTests.swift`
- Create: `Tests/SchneeRunnerAppTests/ProductivityHistoryStoreTests.swift`
- Modify: `Sources/SchneeRunnerApp/TimerCoordinator.swift`
- Modify: `Sources/SchneeRunnerApp/PomodoroCoordinator.swift`
- Modify: `Sources/SchneeRunnerApp/ReminderCoordinator.swift`

**Interfaces:**
- Produces `ProductivityHistoryEntry` for countdown completion, Pomodoro focus completion, Pomodoro break completion, and reminder delivery/acknowledgement when observable.
- Produces `ProductivityHistory.appending(_:)` that keeps only the newest 500 entries.
- Produces separate versioned `history.json` store with the same staged/atomic safety contract as state persistence.
- Domain completion remains committed even if history persistence separately fails.

- [ ] **Step 1: Write failing history-cap and ordering tests**

Append 501 deterministic entries and assert count is 500 and the oldest entry was evicted.

- [ ] **Step 2: Write failing history-store tests**

Cover round-trip, malformed/unsupported file rejection, atomic-failure preservation, and a coordinator test proving timer completion is not rolled back when history save fails.

- [ ] **Step 3: Implement Core history and store**

Keep state/history files independent as required by the spec.

- [ ] **Step 4: Verify history/coordinator tests and quality gates**

Expected: PASS.

- [ ] **Step 5: Commit**

Commit as `feat: record productivity history`.

### Task 9: Management UI and Reminder Editing

**Files:**
- Create: `Sources/SchneeRunnerApp/ProductivityManagementWindowController.swift`
- Create: `Sources/SchneeRunnerApp/ReminderEditorController.swift`
- Create: `Sources/SchneeRunnerApp/PomodoroSettingsController.swift`
- Create: `Tests/SchneeRunnerAppTests/ProductivityManagementWindowControllerTests.swift`
- Create: `Tests/SchneeRunnerAppTests/ReminderEditorControllerTests.swift`
- Create: `Tests/SchneeRunnerAppTests/PomodoroSettingsControllerTests.swift`
- Modify: `Sources/SchneeRunnerApp/StatusMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/AppDelegate.swift`

**Interfaces:**
- Management window presents timers, reminders, Pomodoro settings, and bounded history without moving domain/persistence logic into views.
- Reminder editor supports one-shot/daily/weekday schedule selection, enable/disable, edit/delete, and validation feedback.
- Pomodoro settings expose all durations, long-break cadence, and auto-start setting.
- Status menu only exposes compact summaries plus `Manage Timers…`, `New Reminder…`, `Manage Reminders…`, and `Settings…` entry points.

- [ ] **Step 1: Write failing controller tests for validation and callbacks**

Pin invalid reminder hour/minute rejection, empty weekday selection rejection, Pomodoro positive-duration validation, and callback forwarding to coordinators.

- [ ] **Step 2: Run UI-controller tests and confirm RED**

Run: `swift test --filter ProductivityManagementWindowControllerTests` plus editor/settings suites.

- [ ] **Step 3: Implement AppKit controllers with narrow coordinator callbacks**

Keep view/controller logic declarative and side effects behind coordinators.

- [ ] **Step 4: Verify App tests and quality gates**

Expected: PASS.

- [ ] **Step 5: Commit**

Commit as `feat: add productivity management UI`.

### Task 10: Character Reactions, App Startup Reconciliation, and End-to-End Regression

**Files:**
- Create: `Sources/SchneeRunnerCore/ProductivityCharacterStatePolicy.swift`
- Create: `Sources/SchneeRunnerCore/ProductivityCharacterReactionStore.swift`
- Create: `Sources/SchneeRunnerApp/ProductivityCharacterStateCoordinator.swift`
- Create: `Tests/SchneeRunnerCoreTests/ProductivityCharacterStatePolicyTests.swift`
- Create: `Tests/SchneeRunnerCoreTests/ProductivityCharacterReactionStoreTests.swift`
- Create: `Tests/SchneeRunnerAppTests/ProductivityCharacterStateCoordinatorTests.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterStateCoordinator.swift`
- Modify: `Sources/SchneeRunnerApp/AppDelegate.swift`
- Modify: `Sources/SchneeRunnerApp/StatusMenuController.swift`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `README.md`

**Interfaces:**
- Produces `ProductivityCharacterStatePolicy.state(for:) -> CharacterState?` with internal precedence: reminder fired > timer completed > final minute > Pomodoro focus > active countdown > break.
- Produces `ProductivityCharacterReactionStore` backed by `UserDefaults`, default `true`.
- `CharacterStateCoordinator` gains `setProductivityState(_ state: CharacterState?)` using one trigger ID `productivity` at `.event` priority.
- `ProductivityCharacterStateCoordinator` aggregates timers/Pomodoro/reminder transient events and calls only that narrow CharacterStateCoordinator interface.
- App startup order becomes: load persisted productivity state → reconcile deadlines/recurrence → synchronize pending notifications → build menu/UI state → publish productivity character state → start refresh loops.

- [ ] **Step 1: Write failing policy tests**

Cover each precedence pair, global toggle default true, toggle false suppressing the trigger, and manual priority still winning after productivity updates.

- [ ] **Step 2: Write failing startup/integration tests**

Cover restart with running timer, overdue timer completed once, recurring reminder rebuilt, denied notification permission, and event-tracking refresh while existing animation/CPU behavior remains operational.

- [ ] **Step 3: Run productivity and CharacterState suites and confirm RED**

Run:

```bash
swift test --filter Productivity
swift test --filter CharacterStateCoordinatorTests
```

- [ ] **Step 4: Implement reaction policy and final AppDelegate integration**

Do not alter existing metric/system/manual priorities; add only the single productivity trigger boundary.

- [ ] **Step 5: Update architecture and README**

Document the deadline-authoritative pipeline, persistence files, notification ownership prefixes, user-facing timer/Pomodoro/reminder functionality, and reaction toggle.

- [ ] **Step 6: Run the full local verification suite**

Run:

```bash
swift test
swiftformat --lint .
swiftlint lint --strict
```

Then run any repository scripts/workflows documented by `docs/QUALITY.md` that are applicable locally. Expected: all pass with no new warnings.

- [ ] **Step 7: Open final integration PR and verify required CI**

Required outcome: all repository required checks pass, no unresolved review conversations remain, branch is current with `main`, and no unrelated files are changed.

- [ ] **Step 8: Squash merge**

Use an intent-oriented squash title such as `feat: add productivity timers and reminders` only after required checks are green.

## Plan Self-Review Result

- **Spec coverage:** Countdown, Pomodoro, reminders, snooze, multiple timers, persistence, notification authorization/synchronization, restart/sleep reconciliation, history, management UI, character reactions, documentation, and acceptance tests all map to explicit tasks.
- **Step scan:** Every implementation task follows a RED → minimal implementation → PASS → commit cycle; setup is folded into the task that needs it.
- **Type consistency:** Snapshot is introduced before runtime coordinators; the notification protocol precedes Pomodoro/reminder coordinators; CharacterState integration remains a single final boundary.
- **Review Focus:** All five high-risk conditions are assigned to concrete tests in their owning tasks.
- **Proportion:** The plan defines interfaces and observable tests rather than implementation bodies; no TBD/TODO placeholders remain.
