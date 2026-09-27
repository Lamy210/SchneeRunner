# SchneeRunner Architecture

## 1. Goals

SchneeRunner is a local-first macOS menu bar animation engine for user-supplied character assets.

The architecture should preserve these properties:

- character artwork is data, not application-specific code;
- animation timing is independent from rendering;
- system metrics and external events are independent from animation clips;
- AppKit and Mach APIs stay at the application/platform boundary;
- imported assets are read-only unless an explicit SchneeRunner-owned copy is introduced later;
- network access is not required for the core experience.

## 2. Current vertical slice

```text
NSApplication
     |
     v
AppDelegate
     |
     +----> NSStatusItem
     |
     +----> AnimationController
     |
     +----> SpriteSheetLoader
     |            |
     |            v
     |      SpriteSheetGrid
     |
     +----> CPUMonitor
                  |
                  +----> SystemCPUUsageSampler
                  |
                  +----> CPUUsageCalculator
                  +----> ExponentialMovingAverage
                  +----> AdaptiveAnimationSpeedPolicy
```

### SchneeRunnerCore

Owns deterministic and reusable domain behavior:

- sprite-sheet grid validation;
- frame geometry;
- sprite-sheet decoding;
- CPU tick-delta utilization calculation;
- CPU utilization smoothing;
- utilization-to-animation-pace policy.

It must not own menu bar state, application lifecycle, timers, or macOS host-statistics calls.

### SchneeRunnerApp

Owns macOS integration:

- application lifecycle;
- `NSStatusItem`;
- `NSOpenPanel`;
- animation scheduling;
- Mach host CPU sampling;
- CPU sampling timer;
- menu-bar image sizing;
- user-facing error/state presentation.

UI mutation stays on the main actor.

## 3. Metric pipeline

The CPU pipeline deliberately separates operating-system sampling from policy:

```text
Mach host_cpu_load_info
          |
          v
SystemCPUUsageSampler
          |
          v
CPUTickSnapshot
          |
          v
CPUUsageCalculator
          |
          v
raw utilization
          |
          v
ExponentialMovingAverage
          |
          v
smoothed utilization
          |
          v
AdaptiveAnimationSpeedPolicy
          |
          v
AnimationPace
          |
          v
AnimationController
```

The calculator uses differences between cumulative CPU tick snapshots. A counter regression invalidates the current sampling window rather than producing a bogus utilization value.

The default smoother uses an EMA alpha of 0.25.

The speed policy applies hysteresis around its thresholds to avoid rapid pace changes near a boundary.

## 4. Planned boundaries

The target model remains:

```text
MetricProvider ----+
EventProvider -----+--> TriggerEngine --> CharacterState
                                      |
                                      v
CharacterAsset --> AnimationLibrary --> AnimationPlayer --> Renderer
                                                        |
                                  +---------------------+------------------+
                                  |                                        |
                           MenuBarRenderer                         DesktopRenderer
```

These concepts must remain separable:

```text
CharacterAsset != AnimationClip != Trigger != Metric != Renderer
```

A metric provider emits values. It must not directly manipulate a renderer.

## 5. Asset safety

The current PoC reads the user-selected PNG directly and does not mutate it.

Future persistent imports should copy assets only into an explicitly SchneeRunner-owned application-support directory. Source images must never be moved, renamed, overwritten, or deleted as part of import.

Third-party character art is not part of the application distribution by default.

## 6. Failure handling

Boundary failures must become actionable errors.

Examples:

- unreadable image;
- image without decodable bitmap data;
- incompatible sprite-sheet dimensions;
- frame crop failure;
- unavailable Mach host statistics.

Loading a bad asset must not terminate the application or replace the last valid animation.

A transient CPU sampling failure does not terminate playback. The menu reports CPU availability and keeps the current animation speed.

## 7. Performance direction

Menu bar playback is intentionally small.

Measure:

- frame decode time;
- retained decoded-frame memory;
- timer wakeups;
- CPU usage at each supported FPS;
- impact of one-second metric sampling.

Assets are decoded on import rather than decoded again for every displayed frame.

The animation timer is not restarted when a CPU sample resolves to the already-active FPS.

## 8. Deferred decisions

The following remain deliberately deferred:

- Xcode project layout;
- sandboxing and entitlements;
- persistent character-pack schema;
- GIF/APNG/WebP decoding policy;
- launch-at-login mechanism;
- signed/notarized release configuration;
- generalized metric/event provider protocols;
- desktop rendering.

Each should be introduced with its own focused change and verification path.
