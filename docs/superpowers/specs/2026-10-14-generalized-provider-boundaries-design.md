# Generalized Metric / Event Provider Boundaries Design

## Status

Design for review. This document defines the boundary and migration strategy only; it does not authorize implementation by itself.

## Context

SchneeRunner already separates most deterministic policy from macOS integration, but `CharacterStateCoordinator` still constructs four concrete App-layer monitors directly:

- `SystemBatteryWarningMonitor`
- `SystemMemoryPressureMonitor`
- `LocalBuildEventMonitor`
- `LocalCharacterStateEventMonitor`

The coordinator also wires each monitor through a different callback shape. This makes the trigger-resolution layer depend on concrete IOKit, Dispatch, and Distributed Notification adapters even though the architecture already describes the intended direction as:

```text
MetricProvider ----+
EventProvider -----+--> TriggerEngine --> CharacterState
```

CPU sampling is related but has a different owner. `CPUMonitor` feeds both character state and animation/UI status in `AppDelegate`, so moving CPU ownership into `CharacterStateCoordinator` would conflate responsibilities and is explicitly out of scope.

Several items in the current deferred-decision list are already implemented (Character Pack export and signed/notarized release configuration). The generalized provider boundary is the remaining architecture item addressed by this design.

## Goals

1. Introduce small typed provider protocols for App-layer metric values and discrete events.
2. Make `CharacterStateCoordinator` depend on provider abstractions rather than concrete monitor classes.
3. Preserve existing trigger IDs, priorities, recency behavior, fallback behavior, TTL/expiry semantics, and startup/shutdown ordering.
4. Keep operating-system transport, notification decoding, timer ownership, and source lifecycle in App-layer providers.
5. Keep CharacterState mapping and cross-source trigger resolution out of generalized provider protocols.
6. Make provider-driven coordinator behavior testable with deterministic fakes without IOKit, Dispatch memory-pressure sources, or Distributed Notifications.
7. Allow `CPUMonitor` to conform to the metric-provider boundary without transferring its ownership from `AppDelegate`.

## Non-goals

This change does **not** introduce:

- a plugin system or runtime provider discovery;
- dynamic loading of third-party providers;
- a registry of arbitrary providers;
- Combine, `AsyncSequence`, or a new concurrency model;
- a public package API for external consumers;
- network-backed metric/event sources;
- new trigger priorities or trigger-resolution rules;
- renderer, animation, character-asset, or productivity architecture changes;
- unified error handling for all providers;
- a migration of CPU UI/adaptive-speed ownership into `CharacterStateCoordinator`;
- changes to the local IPC trust model.

YAGNI applies: the first version is intentionally a pair of callback-oriented lifecycle protocols matching the application’s existing architecture.

## Decision

Adopt two `@MainActor` protocols in `SchneeRunnerApp` using Swift primary associated types:

```swift
@MainActor
protocol MetricProvider<Metric>: AnyObject {
    associatedtype Metric

    var onUpdate: ((Metric) -> Void)? { get set }

    func start()
    func stop()
}

@MainActor
protocol EventProvider<Event>: AnyObject {
    associatedtype Event

    var onEvent: ((Event) -> Void)? { get set }

    func start()
    func stop()
}
```

These protocols are App-layer boundaries, not Core domain types. They model acquisition and lifecycle only. They do not know about renderers, animation clips, trigger priority, or trigger IDs.

No type-erasure wrapper is planned initially. Swift 6 constrained existentials such as `any MetricProvider<BatteryWarningLevel>` and `any EventProvider<MemoryPressureLevel>` are preferred. Type erasure should be introduced only if an actual compiler limitation appears during implementation.

## Provider classification

### Metric providers

Metric providers emit a current/repeated value that consumers interpret.

#### `CPUMonitor`

Conforms as:

```text
MetricProvider<CPUMonitor.Update>
```

`AppDelegate` remains its owner and keeps the existing `onError` channel as additional source-specific API. The generalized protocol does not attempt to normalize provider errors in this change.

#### `SystemBatteryWarningMonitor`

Conforms as:

```text
MetricProvider<BatteryWarningLevel>
```

It continues to own IOKit notification-source creation, run-loop registration, deduplication of unchanged warning levels, and cleanup. It emits the raw `BatteryWarningLevel`; `BatteryWarningStatePolicy` remains outside the provider.

### Event providers

Event providers emit discrete source events. They may own source-specific timers needed to preserve transport semantics, but they do not select trigger priority or manipulate the renderer.

#### `SystemMemoryPressureMonitor`

Conforms as:

```text
EventProvider<MemoryPressureLevel>
```

It continues to own the Dispatch memory-pressure source and maps Dispatch flags only into the App/Core-neutral `MemoryPressureLevel`. `MemoryPressureStatePolicy` remains in `CharacterStateCoordinator`.

#### `LocalBuildEventMonitor`

Conforms as:

```text
EventProvider<BuildLifecycleProviderEvent>
```

with a source-specific event shape equivalent to:

```swift
enum BuildLifecycleProviderEvent: Equatable {
    case received(LocalBuildEvent)
    case expired
}
```

The monitor continues to:

- observe the build Distributed Notification;
- decode and validate `LocalBuildEvent`;
- own its one-shot expiry timer;
- cancel/replace the prior timer when a new lifecycle event arrives.

The monitor emits `.received(event)` for each valid event. For a phase whose existing `BuildStatePolicy` effect has a duration, the monitor schedules the same duration and later emits `.expired`.

`CharacterStateCoordinator` applies `BuildStatePolicy` to `.received` events to choose the CharacterState, and clears the build trigger for either a policy effect with no state or `.expired`.

The monitor may consult the deterministic policy only to obtain the existing expiry duration needed for source lifecycle. CharacterState selection itself is performed by the coordinator. This small duplication of a stateless policy lookup is preferred to moving timer ownership into the coordinator or leaking CharacterState-trigger semantics into the provider abstraction.

#### `LocalCharacterStateEventMonitor`

Conforms as:

```text
EventProvider<LocalCharacterStateProviderEvent>
```

with a source-specific event shape equivalent to:

```swift
enum LocalCharacterStateProviderEvent: Equatable {
    case received(LocalCharacterStateEvent)
    case expired(channel: String)
}
```

The monitor continues to:

- observe the local state Distributed Notification;
- decode and validate the payload;
- own independent per-channel TTL timers;
- cancel the prior timer for a channel before handling the replacement event.

It emits the validated source event instead of separate `onSet` / `onClear` callbacks. TTL expiration emits `.expired(channel:)`.

`CharacterStateCoordinator` interprets `.received` actions and performs the existing trigger set/clear behavior. This keeps channel-specific trigger IDs and trigger priority at the coordinator/trigger boundary while preserving timer ownership at the transport boundary.

## Coordinator ownership and dependency injection

`CharacterStateCoordinator` keeps ownership of its four character-state providers, but stores them as constrained provider existentials supplied through the initializer.

Conceptually:

```swift
init(
    playbackController: CharacterPlaybackController,
    batteryWarningProvider: any MetricProvider<BatteryWarningLevel> = SystemBatteryWarningMonitor(),
    memoryPressureProvider: any EventProvider<MemoryPressureLevel> = SystemMemoryPressureMonitor(),
    buildEventProvider: any EventProvider<BuildLifecycleProviderEvent> = LocalBuildEventMonitor(),
    localEventProvider: any EventProvider<LocalCharacterStateProviderEvent> = LocalCharacterStateEventMonitor()
)
```

The default arguments preserve production construction from `AppDelegate`. Tests can inject fakes directly.

The initializer binds provider callbacks using weak captures of the coordinator before any provider is started.

`start()` and `stop()` continue to delegate provider lifecycle. Provider implementations retain the existing idempotent start/stop behavior. The coordinator does not add a second lifecycle state machine unless implementation proves one is necessary.

## Data flow after migration

```text
IOKit battery warning
      |
      v
SystemBatteryWarningMonitor
      |
      | BatteryWarningLevel
      v
MetricProvider
      |
      v
BatteryWarningStatePolicy
      |
      v
CharacterStateCoordinator
      |
      v
CharacterStateTriggerEngine

Dispatch memory pressure
      |
      v
SystemMemoryPressureMonitor
      |
      | MemoryPressureLevel
      v
EventProvider
      |
      v
MemoryPressureStatePolicy
      |
      v
CharacterStateCoordinator
      |
      v
CharacterStateTriggerEngine

Distributed Notification (build)
      |
      v
LocalBuildEventMonitor -- owns expiry timer
      |
      | BuildLifecycleProviderEvent
      v
EventProvider
      |
      v
BuildStatePolicy
      |
      v
CharacterStateCoordinator
      |
      v
CharacterStateTriggerEngine

Distributed Notification (local state)
      |
      v
LocalCharacterStateEventMonitor -- owns per-channel TTL timers
      |
      | LocalCharacterStateProviderEvent
      v
EventProvider
      |
      v
CharacterStateCoordinator
      |
      v
CharacterStateTriggerEngine
```

CPU remains intentionally parallel:

```text
SystemCPUUsageSampler
      |
      v
CPUMonitor : MetricProvider<CPUMonitor.Update>
      |
      v
AppDelegate
   +---> CPU status UI
   +---> AnimationController adaptive pace
   +---> CharacterStateCoordinator.updateCPUState
```

This prevents the provider abstraction from forcing an incorrect ownership change.

## Trigger semantics that must not change

The migration is architecture-only. Existing trigger behavior remains authoritative:

- CPU: trigger ID `cpu`, priority `.metric`;
- battery: `battery-warning`, priority `.systemAdvisory`;
- memory pressure: `memory-pressure`, priority `.systemEvent`;
- build lifecycle: `build`, priority `.event`;
- local event: `local-event:<channel>`, priority `.event`;
- productivity: `productivity`, priority `.event`;
- manual override: `manual`, priority `.manual`.

Equal-priority recency remains implemented only by `CharacterStateTriggerEngine`. Providers must not attempt to resolve competition between sources.

Removing or expiring a trigger must expose the next active trigger exactly as before.

## Lifecycle and callback contract

All provider protocols are `@MainActor` because current consumers, timers, run-loop adapters, and coordinator mutation are already main-actor isolated.

Provider implementations must satisfy these behavioral expectations:

1. `start()` is safe to call more than once and does not create duplicate observers/timers/sources.
2. `stop()` is safe to call more than once.
3. `stop()` removes/cancels owned sources and expiry timers.
4. A stopped provider does not intentionally emit new callbacks from owned sources.
5. Callbacks are set before `start()` in production construction.
6. Providers do not retain the coordinator; coordinator callback wiring uses weak capture.

The protocols do not require `deinit` cleanup as a substitute for explicit `stop()`.

## Error handling

No generalized error channel is added in this change.

Existing behavior remains:

- `CPUMonitor` retains its source-specific `onError` callback;
- malformed Distributed Notification payloads are ignored as today;
- failure to create the battery run-loop source leaves that provider inactive without crashing;
- unknown/empty memory-pressure source data produces no event;
- provider failures do not directly mutate renderer state.

A future error model can be designed if multiple provider consumers need uniform health reporting. Adding one now would widen the abstraction without an existing requirement.

## Testing strategy

Implementation is test-driven.

### 1. Protocol/adoption compile coverage

Add tests or generic compile-time helpers proving these conformances:

- `CPUMonitor` -> `MetricProvider<CPUMonitor.Update>`;
- `SystemBatteryWarningMonitor` -> `MetricProvider<BatteryWarningLevel>`;
- `SystemMemoryPressureMonitor` -> `EventProvider<MemoryPressureLevel>`;
- `LocalBuildEventMonitor` -> `EventProvider<BuildLifecycleProviderEvent>`;
- `LocalCharacterStateEventMonitor` -> `EventProvider<LocalCharacterStateProviderEvent>`.

### 2. Coordinator fake-provider tests

Introduce lightweight test fakes implementing the provider protocols. Verify:

- injected providers are started/stopped through the coordinator;
- a battery value follows the existing battery policy and priority;
- a memory-pressure event follows the existing memory policy and priority;
- a build `.received` event sets the same state as today;
- build `.expired` clears only the build trigger;
- a local `.received(.set)` event sets the correct channel-specific trigger;
- a local `.received(.clear)` event clears only the specified channel;
- local `.expired(channel:)` clears only the expired channel;
- a higher-priority manual trigger remains authoritative while provider updates occur;
- clearing/expiry restores the same lower-priority fallback as before.

These tests prove the abstraction can be exercised without real OS sources.

### 3. Existing monitor tests

Preserve and adapt current tests for:

- CPU sample/error behavior;
- battery warning deduplication/lifecycle where covered;
- memory pressure mapping;
- build lifecycle timer expiry;
- local-event per-channel TTL expiry;
- run-loop timer/source scheduling.

The provider refactor must not weaken source-specific behavioral tests.

### 4. Full regression gates

Run the existing Swift tests and repository workflows. The change does not alter release behavior, but the full required CI remains the merge gate.

## Migration sequence

The implementation should be decomposed into reviewable, behavior-preserving steps:

1. Add the two provider protocols and compile/adoption tests.
2. Adapt `CPUMonitor`, battery, and memory monitors without changing owners.
3. Introduce source-specific build/local provider event enums.
4. Adapt build/local monitors to emit their event enums while retaining timer/observer ownership.
5. Add initializer injection and event wiring to `CharacterStateCoordinator`.
6. Add fake-provider coordinator tests before removing the old concrete callback wiring.
7. Remove obsolete `onChange`, `onSet`, and `onClear` callback surfaces once all consumers use the provider protocols.
8. Update `docs/ARCHITECTURE.md` to show the implemented boundary and clean stale deferred bullets.
9. Run full CI and review the diff for accidental priority/lifecycle changes.

No step should alter user-visible behavior.

## Documentation updates after implementation

`docs/ARCHITECTURE.md` should be updated only when the implementation is green. It should:

- describe `MetricProvider` and `EventProvider` as implemented App-layer boundaries;
- retain the distinction between provider acquisition and Core policy;
- state explicitly that CPU provider ownership remains in `AppDelegate`;
- remove `generalized metric/event provider protocols` from deferred decisions;
- remove already-completed deferred bullets for Character Pack export and signed/notarized release configuration;
- leave genuinely deferred items such as Xcode project layout and sandboxing/entitlements untouched.

## Alternatives considered

### Alternative A: Providers emit `CharacterStateTrigger` directly

Rejected for this phase.

It would make `CharacterStateCoordinator` thinner, but it would push trigger IDs, priorities, and CharacterState mapping into OS/transport adapters. That couples acquisition to resolution and makes source implementations responsible for global trigger semantics.

### Alternative B: One protocol per concrete monitor

Rejected as the target design.

Protocols such as `BatteryWarningMonitoring` would improve testability but would not establish the generalized provider boundary already described by the architecture. It would also reproduce nearly identical lifecycle/callback contracts under multiple names.

### Alternative C: Combine publishers or `AsyncSequence`

Rejected for now.

Both can model streams elegantly, but the current application is callback/run-loop based and `@MainActor`. Introducing a reactive or async-stream layer would add cancellation and task-lifecycle machinery without a user-facing requirement. The callback protocols are the smaller migration.

## Risks and mitigations

### Existential / associated-type complexity

**Risk:** constrained existential syntax could expose a Swift compiler limitation in a mutable callback property.

**Mitigation:** validate the smallest protocol/adoption test first. Introduce explicit type erasure only if compilation requires it; do not preemptively add wrappers.

### Duplicate or stale callbacks

**Risk:** moving callback wiring could accidentally retain old `onSet` / `onClear` paths or leave an observer active after stop.

**Mitigation:** migrate one provider at a time, test start/stop and expiry behavior, and remove old callback surfaces only after the new path is covered.

### Trigger-priority regression

**Risk:** a refactor could accidentally move priority decisions into providers or change equal-priority ordering.

**Mitigation:** keep all trigger IDs and priorities in `CharacterStateCoordinator` and retain existing `CharacterStateTriggerEngine` tests plus new fake-provider precedence tests.

### Build/local expiry regression

**Risk:** relocating mapping logic could change the 2-second success, 5-second failure, cancellation, or per-channel TTL behavior.

**Mitigation:** timer ownership remains in the existing monitors; source-specific expiry tests are retained; coordinator tests verify only the emitted event-to-trigger mapping.

## Acceptance criteria

The design is successfully implemented when all of the following are true:

1. `MetricProvider` and `EventProvider` exist in `SchneeRunnerApp` and are `@MainActor` typed lifecycle boundaries.
2. CPU, battery, memory, build, and local-state monitors conform to the appropriate protocol.
3. `CharacterStateCoordinator` can be instantiated entirely with fake character-state providers in tests.
4. The coordinator no longer requires concrete battery/memory/build/local monitor types.
5. CharacterState policies and trigger IDs/priorities are not generalized into provider protocols.
6. Build and local-state monitor timer/observer ownership remains at the transport boundary.
7. CPU remains owned by `AppDelegate`, including CPU status and adaptive animation-speed behavior.
8. Existing trigger precedence, TTL/expiry, fallback, and user-visible behavior are unchanged.
9. Existing and new tests pass, followed by all required CI workflows.
10. `docs/ARCHITECTURE.md` reflects the implemented provider boundary and no longer lists completed work as deferred.
