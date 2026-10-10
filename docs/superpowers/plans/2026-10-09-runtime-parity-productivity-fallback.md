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

- [ ] **Step 1: Write failing runtime-capability tests**

Add tests asserting:
- bare executable (`bundleIdentifier=nil`, URL `/tmp/SchneeRunner`) => system notifications false, launch at login false, fallback true;
- `.app` bundle with release notification opt-out => system notifications false, launch at login true, fallback true;
- `.app` with notifications enabled => system notifications true;
- missing resource URL => bundled resources false without changing other capabilities.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter RuntimeCapabilitiesTests`
Expected: FAIL because `RuntimeCapabilities` does not exist.

- [ ] **Step 3: Implement `RuntimeCapabilities` and route existing notification policy through it**

Keep `SystemNotificationRuntime` as the low-level UserNotifications safety policy if useful, but make application startup derive one immutable capability value instead of having each controller infer packaging independently.

- [ ] **Step 4: Convert the built-in walk cycle to SwiftPM resources**

Update `Package.swift` so `SchneeRunnerApp` processes `Resources`. Store the four real PNG files under the target resource tree and make `BuiltInCharacterResources` resolve them from the injected bundle. Preserve the existing overload that accepts a resource root only if existing tests still need it.

- [ ] **Step 5: Make release packaging copy the SwiftPM resource bundle instead of decoding a second base64 source**

The release script must package the SwiftPM resource bundle produced for `SchneeRunnerApp`, verify all four PNGs are readable, and stop maintaining an independent top-level image source.

- [ ] **Step 6: Run focused and full tests**

Run: `swift test --filter RuntimeCapabilitiesTests`
Expected: PASS.

Run: `swift test --filter BuiltInCharacterResourcesTests`
Expected: PASS in both explicit-root and module-resource cases that remain supported.

Run: `swift test`
Expected: PASS with no existing startup/resource regression.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/SchneeRunnerApp Resources scripts/ci/build-release-artifact.sh Tests/SchneeRunnerAppTests
git commit -m "feat: unify runtime capabilities and app resources"
```

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

- [ ] **Step 1: Write failing presentation-abstraction tests**

Test event equality/content and a recording fake that can observe calls without constructing AppKit windows.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter ProductivityFallbackPresentationTests`
Expected: FAIL because the event/protocol do not exist.

- [ ] **Step 3: Implement the event/protocol and AppKit presenter**

Keep AppKit presentation non-fatal. Do not let dismissal or presentation failure mutate Timer/Pomodoro/Reminder state. Keep window/panel lifetime owned by the presenter rather than by domain coordinators.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --filter ProductivityFallbackPresentationTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SchneeRunnerApp/ProductivityFallbackPresentation.swift Sources/SchneeRunnerApp/AppKitProductivityFallbackPresenter.swift Tests/SchneeRunnerAppTests/ProductivityFallbackPresentationTests.swift
git commit -m "feat: add in-process productivity fallback presenter"
```

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

- [ ] **Step 1: Add RED tests for completion callbacks**

Assert a timer reconciled across its deadline fires `onTimerCompleted` exactly once even across repeated reconcile calls. Assert a Pomodoro phase transition fires `onPhaseCompleted` once and repeated refresh at the same state does not duplicate it.

- [ ] **Step 2: Run coordinator tests and verify RED**

Run: `swift test --filter TimerCoordinatorTests`
Run: `swift test --filter PomodoroCoordinatorTests`
Expected: FAIL because completion callbacks are absent.

- [ ] **Step 3: Implement completion callbacks at the same transition points that record history**

Do not derive completion from UI refresh count. Use the existing newly-completed / phase-transition logic so history and fallback delivery share one authoritative transition.

- [ ] **Step 4: Add RED controller/E2E tests for disabled notifications**

With a scheduler returning `.disabled` and a recording fallback presenter:
- starting a timer persists/renders immediately;
- reconciling after deadline yields one `.timerCompleted` fallback event;
- Pomodoro phase completion yields one `.pomodoroPhaseCompleted` fallback event;
- notification status `.scheduled` yields no fallback event.

- [ ] **Step 5: Inject the fallback presenter through `ProductivityApplicationController` into Timer/Pomodoro controllers**

Default production wiring uses `AppKitProductivityFallbackPresenter`; tests inject a recording fake.

- [ ] **Step 6: Run focused and full tests**

Run: `swift test --filter ProductivityFallbackFlowTests`
Expected: PASS.

Run: `swift test --filter TimerApplicationControllerTests`
Run: `swift test --filter PomodoroApplicationControllerTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SchneeRunnerApp/TimerCoordinator.swift Sources/SchneeRunnerApp/TimerApplicationController.swift Sources/SchneeRunnerApp/PomodoroCoordinator.swift Sources/SchneeRunnerApp/PomodoroApplicationController.swift Sources/SchneeRunnerApp/ProductivityApplicationController.swift Tests/SchneeRunnerAppTests
git commit -m "feat: deliver timer and pomodoro fallback completions"
```

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

- [ ] **Step 1: Write RED due-evaluation tests**

Cover one-shot, daily, weekday, snooze, disabled reminder, not-yet-due reminder, and a delayed evaluation interval spanning sleep/wake.

- [ ] **Step 2: Write RED duplicate-suppression tests**

After recording one concrete occurrence ID, reevaluating the same time window must not redeliver. A later daily/weekday occurrence must produce a new ID and deliver normally.

- [ ] **Step 3: Run tests and verify RED**

Run: `swift test --filter InProcessReminderSchedulerTests`
Expected: FAIL because the scheduler/store do not exist.

- [ ] **Step 4: Implement occurrence calculation using existing reminder semantics**

Do not duplicate the recurrence rules in an unrelated format. Reuse existing `nextOccurrence(after:calendar:)` and snooze `fireDate`, evaluate the interval since the prior tick, and use a bounded persisted occurrence-ID set only for fallback dedupe.

- [ ] **Step 5: Wire scheduler lifecycle only when system notifications are unavailable**

`ReminderApplicationController.start()` starts fallback scheduling in the unavailable path and `stop()` always tears it down. Delivered fallback reminder events must also feed the existing reminder-fired character reaction exactly once.

- [ ] **Step 6: Run focused and full tests**

Run: `swift test --filter InProcessReminderSchedulerTests`
Run: `swift test --filter ReminderApplicationControllerTests`
Run: `swift test --filter ProductivityFallbackFlowTests`
Expected: PASS.

Run: `swift test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SchneeRunnerApp/InProcessReminderScheduler.swift Sources/SchneeRunnerApp/ReminderFallbackDeliveryStore.swift Sources/SchneeRunnerApp/ReminderApplicationController.swift Sources/SchneeRunnerApp/ProductivityApplicationController.swift Tests/SchneeRunnerAppTests
git commit -m "feat: add in-process reminder fallback scheduling"
```

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

- [ ] **Step 1: Add RED Launch at Login availability tests**

Assert bare runtime produces a disabled unavailable item and invoking its action does not call the service. Assert packaged-capable runtime preserves enabled/notRegistered/requiresApproval behavior.

- [ ] **Step 2: Add RED unsigned-runtime integration tests**

Create one application-level fixture with system notifications unavailable and assert:
- Timer can start and persist;
- Pomodoro can start and persist;
- Reminder can be created and later delivered through fallback while the app is running;
- all productivity controllers start without constructing `UNUserNotificationCenter`;
- missing built-in character resources do not prevent menu/controller startup.

- [ ] **Step 3: Implement capability-aware Launch at Login behavior**

Keep the existing `SMAppService` behavior unchanged when capability is available. The unsupported path must be explicit rather than exception-driven.

- [ ] **Step 4: Run focused tests**

Run: `swift test --filter LaunchAtLoginMenuControllerTests`
Run: `swift test --filter UnsignedRuntimeParityTests`
Expected: PASS.

- [ ] **Step 5: Run full verification for Plan A**

Run: `swift test`
Expected: all tests PASS.

Run the repository's normal Swift formatting/lint commands and the packaged `.app` launch smoke used by CI.
Expected: PASS; unsigned release still has system notifications disabled at bundle level and starts successfully.

- [ ] **Step 6: Commit**

```bash
git add Sources/SchneeRunnerApp/LaunchAtLoginMenuController.swift Sources/SchneeRunnerApp/StatusMenuController.swift Tests/SchneeRunnerAppTests
git commit -m "feat: complete unsigned runtime parity"
```

---

## Completion Status

Implemented and verified in PR #147. All five tasks above are complete. The final functional head before this documentation update was `9779783d8f3650e96f7923fe1040bad90944b26a`, with Tests, Swift Quality, Release Isolation TDD, Test Infrastructure, Quality, and SchneeRunner CI all successful. The Japanese localization and release-resource hardening work remains intentionally separate in `docs/superpowers/plans/2026-10-09-japanese-localization-release-hardening.md`.
