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
     +----> CharacterPlaybackController
     |            |
     |            +----> CharacterAnimationLibrary
     |            |
     |            v
     +----> AnimationController
     |            |
     |            v
     |      AnimationSchedule
     |
     +----> SpriteSheetLoader
     |            |
     |            v
     |      SpriteSheetGrid
     |
     +----> ProceduralImageFrameGenerator
     |            |
     |            v
     |      ProceduralRunCycle
     |
     +----> PNGSequenceLoader
     |
     +----> GIFAnimationLoader ----> LoadedAnimation
     |
     +----> CharacterPackLoader ----> CharacterAnimationLibrary
     |
     +----> CharacterLibraryController
     |            |
     |            +----> CharacterAssetStore
     |            |
     |            +----> PNGSequenceAssetStore
     |            |
     |            +----> GIFAssetStore
     |            |
     |            +----> CharacterPackStore
     |            |
     |            +----> CharacterSelectionStore
     |
     +----> CPUMonitor
                  |
                  +----> SystemCPUUsageSampler
                  |
                  +----> CPUUsageCalculator
                  +----> ExponentialMovingAverage
                  +----> AdaptiveAnimationSpeedPolicy
                               |
                               v
                         CharacterStatePolicy
```

### SchneeRunnerCore

Owns deterministic and reusable domain behavior:

- sprite-sheet grid validation;
- frame geometry;
- sprite-sheet decoding;
- single-image procedural frame generation;
- procedural run-cycle transforms;
- ordered multi-file PNG sequence loading;
- GIF frame decoding with authored per-frame timing;
- frame/schedule pairing through `LoadedAnimation`;
- character state modeling and CPU-pace-to-state policy;
- state-aware animation lookup with deterministic default fallback;
- Character Pack v1 manifest validation and safe relative-path resolution;
- state-specific pack loading into `CharacterAnimationLibrary`;
- character metadata and owned-copy persistence;
- multi-file sequence persistence;
- GIF owned-copy persistence;
- canonical character-pack owned-copy persistence;
- last-selected character preference persistence;
- pre-decode image metadata and resource-limit validation;
- CPU tick-delta utilization calculation;
- CPU utilization smoothing;
- utilization-to-animation-pace policy;
- validated animation frame timing schedules and playback-rate scaling.

It must not own menu bar state, application lifecycle, timers, or macOS host-statistics calls.

### SchneeRunnerApp

Owns macOS integration:

- application lifecycle;
- `NSStatusItem`;
- `NSOpenPanel`;
- animation scheduling;
- requested-state playback coordination;
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
CharacterStatePolicy
          |
          v
CharacterState
          |
          v
CharacterPlaybackController
          |
          +----> CharacterAnimationLibrary
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

Current one-clip characters expose that clip as the animation library's default `run` state. Requests for unavailable states resolve to the default clip, and the playback coordinator avoids restarting the animation when multiple requested states resolve to the same clip.

## 5. Asset safety

The current PoC reads the user-selected PNG directly and does not mutate it.

Imported assets are copied into a SchneeRunner-owned Application Support directory using a staging directory followed by a final directory move. Source images are never moved, renamed, overwritten, or deleted as part of import.

Each stored character uses a UUID directory and a JSON manifest. Single-image and sprite-sheet assets use `source.png`, GIF assets use `source.gif`, PNG sequences use a `frames/` directory with zero-padded frame names, and character packs use an owned `package.schneerunner/` directory containing only referenced clips in canonical paths. A failed persistence attempt cleans up its staging directory and does not prevent the already-decoded animation from running. Image imports are inspected with ImageIO before decode; type, frame count, file size, dimensions, and pixel count must satisfy the configured validation policy. PNG sequences also enforce aggregate file-byte and decoded-pixel budgets across all frames and revalidate the owned copies before the staged directory becomes visible. GIFs enforce file, frame-count, dimension, and aggregate decoded-pixel limits; the copied GIF is fully decoded before its staged directory is committed.

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

Assets are decoded on import rather than decoded again for every displayed frame. Single-image mode renders a bounded 64-point-high working animation instead of retaining eight full-resolution copies of the source.

The animation timer is not restarted when a CPU sample resolves to the already-active FPS. Playback uses one-shot frame timers derived from an immutable base schedule and a separate playback-rate multiplier. Uniform frame animations use a 12 FPS reference schedule, so the existing 6 / 8 / 12 / 18 / 24 FPS controls preserve their current effective timing while authored per-frame durations can be introduced without changing the renderer.

## 8. Deferred decisions

The following remain deliberately deferred:

- Xcode project layout;
- sandboxing and entitlements;
- character-pack export and future schema versions;
- APNG/WebP decoding policy;
- launch-at-login mechanism;
- signed/notarized release configuration;
- generalized metric/event provider protocols;
- desktop rendering.

Each should be introduced with its own focused change and verification path.
