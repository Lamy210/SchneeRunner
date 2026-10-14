# Generalized Provider Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `CharacterStateCoordinator`'s concrete battery/memory/build/local monitor dependencies with typed `MetricProvider` / `EventProvider` boundaries without changing trigger, lifecycle, expiry, CPU ownership, or user-visible behavior.

**Architecture:** Add two `@MainActor` primary-associated-type protocols in the App target. Adapt existing monitors incrementally while preserving temporary compatibility callbacks, then inject constrained provider existentials into `CharacterStateCoordinator`, move build/local CharacterState mapping to the coordinator, and finally remove obsolete callback surfaces. CPU adopts the metric boundary but remains owned and consumed by `AppDelegate`.

**Tech Stack:** Swift 6.0, Swift Package Manager, XCTest, AppKit, IOKit, Dispatch, DistributedNotificationCenter, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-14-generalized-provider-boundaries-design.md`

## Global Constraints

- `MetricProvider` and `EventProvider` are App-layer acquisition/lifecycle boundaries, not Core domain types.
- All provider protocols remain `@MainActor` and class-bound.
- CPU ownership stays in `AppDelegate`; do not move CPU UI/adaptive-speed responsibilities into `CharacterStateCoordinator`.
- Preserve trigger IDs, priorities, equal-priority recency, fallback behavior, TTL/expiry durations, startup/shutdown ordering, and user-visible behavior exactly.
- Keep OS transport, notification decoding, source/timer ownership, and cleanup inside provider implementations.
- Keep CharacterState mapping and trigger resolution out of generalized provider protocols.
- Do not add Combine, `AsyncSequence`, runtime discovery, type erasure, a registry, or a generalized error channel unless the compiler proves a concrete need.
- Pull-request workflows remain secret-free; this change must not touch signing/notarization credentials or release authority.

## Review Focus

- Repeated `start()` / `stop()` calls must remain idempotent and must not duplicate or leak observers, run-loop sources, dispatch sources, or timers.
- Build success/failure expiry must remain 2s/5s respectively; cancellation must clear immediately and must not leave a stale timer.
- Local-state TTL replacement/clear/expiry must affect only the addressed channel and preserve other channel triggers.
- Manual/higher-priority triggers must remain authoritative while provider callbacks arrive; clearing/expiry must reveal the same lower-priority fallback as before.
- Provider migration must not introduce duplicate delivery by leaving both legacy callbacks and the new generalized callback wired to `CharacterStateCoordinator` at the same time.

---

### Task 1: Add provider protocols and metric/system provider adoption

**Files:**
- Create: `Sources/SchneeRunnerApp/ProviderProtocols.swift`
- Modify: `Sources/SchneeRunnerApp/CPUMonitor.swift`
- Modify: `Sources/SchneeRunnerApp/SystemBatteryWarningMonitor.swift`
- Modify: `Sources/SchneeRunnerApp/SystemMemoryPressureMonitor.swift`
- Create: `Tests/SchneeRunnerAppTests/ProviderProtocolsTests.swift`

**Interfaces:**
- Produces: `@MainActor protocol MetricProvider<Metric>: AnyObject` with `var onUpdate: ((Metric) -> Void)?`, `start()`, and `stop()`.
- Produces: `@MainActor protocol EventProvider<Event>: AnyObject` with `var onEvent: ((Event) -> Void)?`, `start()`, and `stop()`.
- Produces: `CPUMonitor: MetricProvider<CPUMonitor.Update>`.
- Produces: `SystemBatteryWarningMonitor: MetricProvider<BatteryWarningLevel>`.
- Produces: `SystemMemoryPressureMonitor: EventProvider<MemoryPressureLevel>`.

- [ ] **Step 1: Write compile/adoption tests**

Add XCTest coverage that assigns each concrete provider to the corresponding constrained existential and verifies callback delivery using deterministic callable seams where already available. The compile assertions must fail before the conformances exist.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --filter ProviderProtocolsTests`

Expected: FAIL because `MetricProvider` / `EventProvider` and required conformances do not exist.

- [ ] **Step 3: Add the two provider protocols**

Create `ProviderProtocols.swift` with exactly the lifecycle/callback requirements defined by the spec. Do not add error, priority, renderer, trigger, or registry concepts.

- [ ] **Step 4: Adapt CPU, battery, and memory providers minimally**

Keep `CPUMonitor.onUpdate` as-is. Rename/add the generalized callback on battery and memory while temporarily preserving a compatibility alias only if needed to keep the current coordinator compiling until Task 3. Do not change sampling, IOKit, Dispatch, deduplication, timer/source, or cleanup behavior.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `swift test --filter ProviderProtocolsTests`

Expected: PASS.

- [ ] **Step 6: Run existing CPU/battery/memory tests**

Run the existing focused XCTest suites for `CPUMonitor`, battery warning, and memory pressure. Expected: PASS with unchanged behavior.

- [ ] **Step 7: Commit**

Commit message: `refactor: add typed provider boundaries`

---

### Task 2: Convert build/local monitors to source-event providers

**Files:**
- Modify: `Sources/SchneeRunnerApp/LocalBuildEventMonitor.swift`
- Modify: `Sources/SchneeRunnerApp/LocalCharacterStateEventMonitor.swift`
- Modify: `Tests/SchneeRunnerAppTests/LocalBuildEventMonitorTests.swift`
- Modify: `Tests/SchneeRunnerAppTests/LocalCharacterStateEventMonitorTests.swift`
- Modify: `Tests/SchneeRunnerAppTests/ProviderProtocolsTests.swift`

**Interfaces:**
- Produces: `enum BuildLifecycleProviderEvent: Equatable { case received(LocalBuildEvent); case expired }`.
- Produces: `LocalBuildEventMonitor: EventProvider<BuildLifecycleProviderEvent>`.
- Produces: `enum LocalCharacterStateProviderEvent: Equatable { case received(LocalCharacterStateEvent); case expired(channel: String) }`.
- Produces: `LocalCharacterStateEventMonitor: EventProvider<LocalCharacterStateProviderEvent>`.

- [ ] **Step 1: Write failing event-shape and expiry tests**

Add tests proving:
- valid build input emits `.received(event)`;
- build expiry emits `.expired` while event-tracking run-loop mode is active;
- cancellation replaces/cancels any previous build expiry and does not emit a later stale expiry;
- local set/clear emits `.received(event)` without doing trigger mapping;
- local TTL expiry emits `.expired(channel:)` only for the active timer;
- replacing a channel timer suppresses stale expiry for that channel while other channels remain independent.

- [ ] **Step 2: Run focused tests and verify RED**

Run: `swift test --filter LocalBuildEventMonitorTests && swift test --filter LocalCharacterStateEventMonitorTests && swift test --filter ProviderProtocolsTests`

Expected: FAIL because provider-event enums and `onEvent` delivery do not exist.

- [ ] **Step 3: Implement build provider-event delivery**

Emit `.received(LocalBuildEvent)` for each valid decoded payload. Retain monitor ownership of the existing one-shot expiry timer and emit `.expired` on expiry. Consult `BuildStatePolicy` only for the existing expiry duration needed by source lifecycle; do not emit `CharacterState` through the generalized callback.

- [ ] **Step 4: Implement local-state provider-event delivery**

Emit `.received(LocalCharacterStateEvent)` for each valid decoded event. Retain per-channel timer ownership and emit `.expired(channel:)` from the active timer only.

- [ ] **Step 5: Preserve temporary legacy callback compatibility**

Until Task 3 switches `CharacterStateCoordinator`, keep legacy callback surfaces only as a transition aid. Ensure the generalized callback and legacy callbacks are not both consumed by the coordinator simultaneously.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run the three focused test suites from Step 2. Expected: PASS.

- [ ] **Step 7: Commit**

Commit message: `refactor: expose build and local provider events`

---

### Task 3: Inject providers into `CharacterStateCoordinator`

**Files:**
- Modify: `Sources/SchneeRunnerApp/CharacterStateCoordinator.swift`
- Modify: `Tests/SchneeRunnerAppTests/CharacterStateCoordinatorTests.swift`

**Interfaces:**
- Consumes: `any MetricProvider<BatteryWarningLevel>`.
- Consumes: `any EventProvider<MemoryPressureLevel>`.
- Consumes: `any EventProvider<BuildLifecycleProviderEvent>`.
- Consumes: `any EventProvider<LocalCharacterStateProviderEvent>`.
- Produces: initializer defaults that preserve current production construction from `AppDelegate`.
- Produces: coordinator-owned build policy mapping and local event action/channel mapping.

- [ ] **Step 1: Add deterministic fake providers and failing lifecycle/mapping tests**

In `CharacterStateCoordinatorTests`, add lightweight `@MainActor` fake metric/event providers with start/stop counters and manual `emit` helpers. Add tests proving:
- all injected providers start and stop exactly once per coordinator lifecycle call sequence expected by the existing contract;
- battery values preserve advisory priority and fallback;
- memory events preserve system-event priority and fallback;
- build `.received` preserves started/succeeded/failed/cancelled mapping;
- build `.expired` clears only the build trigger;
- local `.received(.set)` uses `local-event:<channel>` semantics;
- local `.received(.clear)` and `.expired(channel:)` clear only that channel;
- manual override remains authoritative while provider events arrive;
- clearing/expiry restores the same lower-priority state.

- [ ] **Step 2: Run coordinator tests and verify RED**

Run: `swift test --filter CharacterStateCoordinatorTests`

Expected: FAIL because injectable provider parameters and generalized callback wiring do not exist.

- [ ] **Step 3: Add constrained existential dependencies**

Store the four character-state providers behind the constrained existentials defined by the spec. Add default initializer arguments using the existing concrete monitors so `AppDelegate` call sites remain source-compatible.

- [ ] **Step 4: Wire callbacks before provider start**

Use weak captures. Battery and memory map through their existing Core policies. Build `.received` maps through `BuildStatePolicy`, `.expired` removes only the build trigger. Local `.received` interprets set/clear action and `.expired(channel:)` removes only that channel.

- [ ] **Step 5: Keep CPU external**

Do not add CPU as a coordinator-owned dependency. Existing `updateCPUState` / `clearCPUState` remain the AppDelegate-facing bridge.

- [ ] **Step 6: Run coordinator tests and verify GREEN**

Run: `swift test --filter CharacterStateCoordinatorTests`

Expected: PASS.

- [ ] **Step 7: Run the full App test target**

Run: `swift test --filter SchneeRunnerAppTests`

Expected: PASS.

- [ ] **Step 8: Commit**

Commit message: `refactor: inject character state providers`

---

### Task 4: Remove compatibility callbacks, update architecture, and verify regression gates

**Files:**
- Modify: `Sources/SchneeRunnerApp/SystemBatteryWarningMonitor.swift` if a temporary `onChange` compatibility alias remains.
- Modify: `Sources/SchneeRunnerApp/SystemMemoryPressureMonitor.swift` if a temporary `onChange` compatibility alias remains.
- Modify: `Sources/SchneeRunnerApp/LocalBuildEventMonitor.swift`
- Modify: `Sources/SchneeRunnerApp/LocalCharacterStateEventMonitor.swift`
- Modify: monitor tests as needed after legacy callback removal.
- Modify: `docs/ARCHITECTURE.md`

**Interfaces:**
- Final provider surface contains only the generalized callback required by each protocol plus source-specific APIs that are still intentionally needed (for example `CPUMonitor.onError`).

- [ ] **Step 1: Add/adjust tests that fail if legacy paths are still required**

Ensure all monitor and coordinator tests use only `onUpdate` / `onEvent` and injected provider interfaces. No test should rely on `onChange`, `onSet`, or `onClear`.

- [ ] **Step 2: Remove obsolete callback surfaces**

Delete transitional aliases/callbacks and any duplicate CharacterState mapping left in build/local monitors. Keep expiry-duration lookup and transport lifecycle only where the spec requires them.

- [ ] **Step 3: Update `docs/ARCHITECTURE.md`**

Document implemented `MetricProvider` / `EventProvider` App-layer boundaries, keep CPU ownership in `AppDelegate`, and remove only completed deferred bullets for generalized providers, Character Pack export, and signed/notarized release configuration. Leave genuine deferred items unchanged.

- [ ] **Step 4: Run full tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 5: Run formatting/lint/quality checks**

Run the repository-prescribed SwiftFormat and SwiftLint commands from `CONTRIBUTING.md` / `docs/QUALITY.md`, plus any relevant repository automation checks for touched files. Expected: PASS.

- [ ] **Step 6: Inspect final diff**

Confirm no trigger IDs/priorities, release workflows, secrets, package dependencies, user-facing copy, or unrelated refactors changed.

- [ ] **Step 7: Commit**

Commit message: `docs: finalize provider boundary migration`

---

### Task 5: PR, CI, review, and merge gate

**Files:**
- No planned production-file changes unless review finds a confirmed defect.

**Interfaces:**
- Produces: implementation PR targeting `main` with the design/spec and plan linked.

- [ ] **Step 1: Push/open the implementation PR**

Use a short-lived `refactor/*` branch from the current `main` after the approved design PR is merged.

- [ ] **Step 2: Verify all required workflows**

Require successful `Tests`, `Swift Quality`, `Quality`, `Release Isolation TDD`, and `SchneeRunner CI` runs (plus any newly emitted required stable gate). Do not classify failures as flaky without evidence.

- [ ] **Step 3: Perform a whole-branch code review**

Review correctness, provider lifecycle, duplicate callback risk, trigger semantics, timer cancellation, memory ownership/weak captures, architecture boundaries, compatibility, and test failure-detection quality. Classify findings as Confirmed / Likely / False Positive / Intentional / Unknown.

- [ ] **Step 4: Fix only confirmed/justified findings and rerun regression gates**

For each finding compare minimal fix, root fix, design change, and document-only/no-change before editing. Re-run affected tests and full CI after fixes.

- [ ] **Step 5: Merge only when gates are satisfied**

Use the repository's preferred squash merge. Do not merge with unresolved review findings, failed required CI, merge conflict, or compatibility regression.

- [ ] **Step 6: Post-merge verification**

Verify `main` contains the squash result and post-merge workflows remain green. Re-evaluate Issues #142 and #43 plus any new TODO/CI findings before selecting the next development cycle.
