# Unsigned Runtime Parity and Productivity Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `swift run SchneeRunner` and the unsigned packaged app useful for Timer, Pomodoro, Reminder, built-in character loading, and runtime capability-dependent features without Developer ID signing or notarization.

**Architecture:** Centralize runtime capability detection in `SchneeRunnerApp`, keep productivity domain state independent from delivery, and add an injectable AppKit fallback presentation path when system notifications are unavailable. Move the built-in character to SwiftPM-managed resources so development and packaged execution share one source of truth.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, Foundation, UserNotifications, ServiceManagement, XCTest, existing shell release scripts.

**Spec:** `docs/superpowers/specs/2026-10-09-runtime-parity-japanese-localization-design.md`

## Global Constraints

- macOS 14 or later.
- Developer ID signing and Apple notarization are explicitly out of scope.
- Public release remains unsigned and must not weaken or bypass Gatekeeper.
- Timer/Pomodoro/Reminder persisted JSON schema and Application Support paths must remain compatible.
- Character Pack schema, notification identifier prefixes, CLI commands, and distributed-notification payloads must not change.
- System notifications must remain guarded; do not flip `SchneeRunnerSystemNotificationsEnabled` to `true` in unsigned releases.
- No network dependency may be introduced.

## Review Focus

- Bare executable runtime with no bundle identifier: Timer/Pomodoro/Reminder domain state still works and fallback delivery is selected instead of crashing.
- Sleep/wake or delayed run loop: Reminder fallback catches occurrences after the prior evaluation boundary without delivering the same occurrence twice.
- Missing built-in resources: status menu and imports still launch; no startup crash.
- Fallback presentation failure or dismissal: persisted productivity state remains correct and the app keeps running.
- Unsupported Launch at Login runtime: menu item is disabled with an explicit unavailable state and never attempts `SMAppService.register()`.

---

### Task 1: Centralize Runtime Capabilities and Unify Built-in Resources

**Files:**
- Create: `Sources/SchneeRunnerApp/RuntimeCapabilities.swift`
- Modify: `Package.swift`
- Modify: `Sources/SchneeRunnerApp/BuiltInCharacterResources.swift`
- Modify: `Sources/SchneeRunnerApp/StartupCharacterLoader.swift`
- Modify: `Sources/SchneeRunnerApp/AppDelegate.swift`
- Modify: `scripts/ci/build-release-artifact.sh`
- Move source assets into: `Sources/SchneeRunnerApp/Resources/BuiltInCharacters/YukihanaLamy/walk_1.png` ... `walk_4.png`
- Remove after migration: `Resources/BuiltInCharacters/YukihanaLamy/*.png.b64`
- Test: `Tests/SchneeRunnerAppTests/RuntimeCapabilitiesTests.swift`
- Test: `Tests/SchneeRunnerAppTests/BuiltInCharacterResourcesTests.swift`
- Test: existing release-contract tests covering `build-release-artifact.sh`

**Interfaces:**
- Produces: `struct RuntimeCapabilities: Equatable, Sendable` with `systemNotificationsAvailable`, `launchAtLoginAvailable`, `bundledResourcesAvailable`, and `inProcessFallbackAvailable`.
- Produces: `static func detect(bundleIdentifier: String?, bundleURL: URL, notificationsEnabled: Bool, resourceURL: URL?) -> RuntimeCapabilities`.
- Produces: `BuiltInCharacterResources.yukihanaLamyWalkCycle(bundle: Bundle) -> [URL]` using SwiftPM-managed resources.
- Later tasks consume one `RuntimeCapabilities` value created near app startup.

- [x] **Step 1: Write failing runtime-capability tests**
- [x] **Step 2: Run the focused tests and verify RED**
- [x] **Step 3: Implement `RuntimeCapabilities` and route existing notification policy through it**
- [x] **Step 4: Convert the built-in walk cycle to SwiftPM resources**
- [x] **Step 5: Make release packaging copy the SwiftPM resource bundle instead of decoding a second base64 source**
- [x] **Step 6: Run focused and full tests**
- [x] **Step 7: Commit**

---

### Task 2: Add an Injectable In-process Productivity Fallback Presenter

**Files:**
- Create: `Sources/SchneeRunnerApp/ProductivityFallbackPresentation.swift`
- Create: `Sources/SchneeRunnerApp/AppKitProductivityFallbackPresenter.swift`
- Test: `Tests/SchneeRunnerAppTests/ProductivityFallbackPresentationTests.swift`

**Interfaces:**
- Consumes: `RuntimeCapabilities` from Task 1.
- Produces: `enum ProductivityFallbackEvent: Equatable` with `.timerCompleted(title:)`, `.pomodoroPhaseCompleted(phase:)`, and `.reminderDue(title:body:)`.
- Produces: `@MainActor protocol ProductivityFallbackPresenting: AnyObject { func present(_ event: ProductivityFallbackEvent) }`.
- Produces: `AppKitProductivityFallbackPresenter`, which shows an app-owned non-fatal AppKit presentation and plays a system sound.

- [x] **Step 1: Write failing presentation-abstraction tests**
- [x] **Step 2: Run the focused test and verify RED**
- [x] **Step 3: Implement the event/protocol and AppKit presenter**
- [x] **Step 4: Run focused tests and verify GREEN**
- [x] **Step 5: Commit**

---

### Task 3: Wire Timer and Pomodoro Completion to Fallback Delivery

**Files:**
- Modify: `Sources/SchneeRunnerApp/TimerCoordinator.swift`
- Modify: `Sources/SchneeRunnerApp/TimerApplicationController.swift`
- Modify: `Sources/SchneeRunnerApp/PomodoroCoordinator.swift`
- Modify: `Sources/SchneeRunnerApp/PomodoroApplicationController.swift`
- Modify: `Sources/SchneeRunnerApp/ProductivityApplicationController.swift`
- Test: `Tests/SchneeRunnerAppTests/TimerCoordinatorTests.swift`
- Test: `Tests/SchneeRunnerAppTests/TimerApplicationControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/PomodoroCoordinatorTests.swift`
- Test: `Tests/SchneeRunnerAppTests/PomodoroApplicationControllerTests.swift`
- Create: `Tests/SchneeRunnerAppTests/ProductivityFallbackFlowTests.swift`

**Interfaces:**
- Consumes: `ProductivityFallbackPresenting` from Task 2.
- Produces from `TimerCoordinator`: `var onTimerCompleted: ((ProductivityCountdownTimer) -> Void)?` invoked exactly once for a newly completed timer.
- Produces from `PomodoroCoordinator`: `var onPhaseCompleted: ((PomodoroSession, Date) -> Void)?` using the just-completed phase/session and its completion timestamp.
- Controllers track notification delivery status; fallback is used only when system delivery is disabled/unavailable, never as a duplicate second delivery.

- [x] **Step 1: Add RED tests for completion callbacks**
- [x] **Step 2: Run coordinator tests and verify RED**
- [x] **Step 3: Implement completion callbacks at the same transition points that record history**
- [x] **Step 4: Add RED controller/E2E tests for disabled notifications**
- [x] **Step 5: Inject the fallback presenter through `ProductivityApplicationController` into Timer/Pomodoro controllers**
- [x] **Step 6: Run focused and full tests**
- [x] **Step 7: Commit**

---

### Task 4: Add In-process Reminder Scheduling with Duplicate Suppression

**Files:**
- Create: `Sources/SchneeRunnerApp/InProcessReminderScheduler.swift`
- Create: `Sources/SchneeRunnerApp/ReminderFallbackDeliveryStore.swift`
- Modify: `Sources/SchneeRunnerApp/ReminderApplicationController.swift`
- Modify: `Sources/SchneeRunnerApp/ProductivityApplicationController.swift`
- Test: `Tests/SchneeRunnerAppTests/InProcessReminderSchedulerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/ReminderApplicationControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/ProductivityFallbackFlowTests.swift`

**Interfaces:**
- Consumes: existing `ProductivityReminder`, `ReminderSnooze`, recurrence helpers, and `ProductivityFallbackPresenting`.
- Produces: `@MainActor final class InProcessReminderScheduler` with `start()`, `stop()`, and an injectable `evaluate(now:)` seam for deterministic tests.
- Produces: stable fallback occurrence IDs based on reminder/snooze identity plus the concrete scheduled occurrence time.
- Produces: `ReminderFallbackDeliveryStore` backed by a small bounded UserDefaults value or dedicated app preference, separate from `ProductivitySnapshot` JSON schema.

- [x] **Step 1: Write RED due-evaluation tests**
- [x] **Step 2: Write RED duplicate-suppression tests**
- [x] **Step 3: Run tests and verify RED**
- [x] **Step 4: Implement occurrence calculation using existing reminder semantics**
- [x] **Step 5: Wire scheduler lifecycle only when system notifications are unavailable**
- [x] **Step 6: Run focused and full tests**
- [x] **Step 7: Commit**

---

### Task 5: Make Launch at Login Capability-aware and Add Runtime E2E Coverage

**Files:**
- Modify: `Sources/SchneeRunnerApp/LaunchAtLoginMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/StatusMenuController.swift` only if capability state must be surfaced there
- Test: `Tests/SchneeRunnerAppTests/LaunchAtLoginMenuControllerTests.swift`
- Create: `Tests/SchneeRunnerAppTests/UnsignedRuntimeParityTests.swift`

**Interfaces:**
- Consumes: `RuntimeCapabilities.launchAtLoginAvailable`.
- `LaunchAtLoginMenuController` accepts capability availability at initialization; unavailable runtimes never call register/unregister and expose a disabled item.

- [x] **Step 1: Add RED Launch at Login availability tests**
- [x] **Step 2: Add RED unsigned-runtime integration tests**
- [x] **Step 3: Implement capability-aware Launch at Login behavior**
- [x] **Step 4: Run focused tests**
- [x] **Step 5: Run full verification for Plan A**
- [x] **Step 6: Commit**

---

## Completion Status

Implemented and verified in PR #147. All five tasks above are complete. The final functional head before documentation-only completion updates was `9779783d8f3650e96f7923fe1040bad90944b26a`, with Tests, Swift Quality, Release Isolation TDD, Test Infrastructure, Quality, and SchneeRunner CI all successful. The Japanese localization and release-resource hardening work remains intentionally separate in `docs/superpowers/plans/2026-10-09-japanese-localization-release-hardening.md`.
