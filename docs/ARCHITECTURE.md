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
     +----> CharacterFrameRendererCoordinator
     |            |
     |            +----> NSStatusBarButton
     |            |
     |            +----> DesktopCharacterRenderer
     |                         |
     |                         +----> DesktopCharacterPlacementStore
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
     +----> AnimatedImageLoader ---> LoadedAnimation
     |
     +----> CharacterPackLoader ----> CharacterAnimationLibrary
     |
     +----> CharacterPackBuilder
     |
     +----> CharacterLibraryController
     |            |
     |            +----> CharacterAssetStore
     |            |
     |            +----> PNGSequenceAssetStore
     |            |
     |            +----> GIFAssetStore
     |            |
     |            +----> AnimatedImageAssetStore
     |            |
     |            +----> CharacterPackStore
     |            |
     |            +----> CharacterSelectionStore
     |
     +----> LaunchAtLoginMenuController ----> SMAppService.mainApp
     |
     +----> CharacterStateCoordinator
     |            |
     |            +----> CharacterStateTriggerEngine
     |            |
     |            +----> SystemBatteryWarningMonitor
     |            |
     |            +----> BatteryWarningStatePolicy
     |            |
     |            +----> LocalBuildEventMonitor
     |            |
     |            +----> LocalCharacterStateEventMonitor
     |            |
     |            +----> SystemMemoryPressureMonitor
     |            |
     |            +----> MemoryPressureStatePolicy
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
                               |
                               v
                    CharacterStateTriggerEngine
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
- APNG and WebP frame decoding with authored per-frame timing;
- frame/schedule pairing through `LoadedAnimation`;
- character state modeling and CPU-pace-to-state policy;
- battery-warning-to-state policy;
- memory-pressure-to-state policy;
- build-lifecycle-to-trigger-effect policy;
- priority-aware character-state trigger resolution with deterministic recency tie-breaking;
- validated local character-state event payloads, channel identifiers, and TTL constraints;
- versioned local build lifecycle event payloads;
- state-aware animation lookup with deterministic default fallback;
- Character Pack v1 manifest validation and safe relative-path resolution;
- state-specific pack loading into `CharacterAnimationLibrary`, including GIF, APNG, and WebP timing;
- character metadata and owned-copy persistence;
- multi-file sequence persistence;
- GIF owned-copy persistence;
- APNG/WebP owned-copy persistence;
- canonical character-pack owned-copy persistence;
- canonical character-pack export through staged revalidation;
- canonical Character Pack construction from local clip sources;
- last-selected character preference persistence;
- desktop-character placement preference validation and persistence with bounded square geometry;
- desktop-character visibility preference persistence;
- desktop click-through preference persistence;
- deterministic horizontal desktop-motion policy with edge reflection;
- desktop-motion speed presets and preference persistence;
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
- frame fan-out to menu bar and optional desktop renderers;
- transparent draggable/resizable desktop-window rendering;
- desktop-window frame restoration constrained to connected displays;
- explicit desktop placement reset to the current main display;
- runtime desktop-window recovery after display-topology or visible-frame changes;
- timer-driven optional autonomous desktop movement;
- pointer-interaction pause for autonomous desktop movement;
- direction-aware desktop-only horizontal sprite presentation;
- independent desktop-movement speed configuration;
- optional desktop click-through input behavior;
- requested-state playback coordination;
- manual character-state override menu coordination;
- system-managed login-item registration and approval-state presentation;
- local Distributed Notification state-event reception with per-channel TTL expiry;
- local build lifecycle event reception and terminal-state expiry;
- IOKit power-source notification and low-battery warning monitoring;
- Dispatch system memory-pressure monitoring;
- Mach host CPU sampling;
- CPU sampling timer;
- menu-bar image sizing;
- user-facing error/state presentation;
- save-panel coordination for Character Pack export;
- modal Character Pack builder coordination and per-state source selection.

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
CharacterStateTriggerEngine <---- Manual State Override
          ^                    <---- Local State Event
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

The current renderer boundary fans each animation frame out to the menu bar and, when enabled, a transparent desktop window. The desktop renderer is presentation-only: it does not select states, decode assets, or own animation timing. Its last valid frame is stored through a platform-independent placement record that rejects non-finite, out-of-range, and materially non-square geometry; restoration chooses an intersecting connected display and clamps one shared square dimension against that display's visible short edge before clamping the origin. The user's desktop-visibility and click-through choices are persisted independently in Core and applied after App menu callbacks are wired during launch; autonomous movement remains an explicit per-launch opt-in. The AppKit renderer maps click-through mode to `NSPanel.ignoresMouseEvents`, so input passes to applications behind the character without changing renderer or animation state. A menu action can reset the panel to the standard 128-point placement on the current main display and persist that frame without changing autonomous-movement state. The renderer also observes display-parameter changes at runtime and recovers an existing panel onto the best remaining screen, falling back to the main display when the previous screen disappears.

Optional desktop movement is a separate pipeline. `DesktopCharacterMotionController` owns the AppKit timer and reads current window/display geometry, while `DesktopMotionPolicy` deterministically advances only horizontal position and direction. The desktop panel reports active primary-pointer interaction at the AppKit boundary; while the user is dragging or resizing, the controller keeps the timer alive but advances its timestamp without changing position. User-driven move persistence is deferred until the pointer interaction ends, including while autonomous movement is enabled, then motion resumes from the user-selected frame. The motion controller forwards direction changes to the desktop renderer, which mirrors only its presentation layer; the menu bar renderer and source assets are not modified. Movement-speed presets are modeled and persisted in Core, while the App menu owns their presentation. Selecting a preset replaces only the motion policy's points-per-second value and remains independent from animation playback rate. Motion never writes character-state triggers or changes animation playback rate. Programmatic movement is excluded from per-frame placement persistence, with the final frame saved when movement stops.

Current one-clip characters expose that clip as the animation library's default `run` state. Requests for unavailable states resolve to the default clip, and the playback coordinator avoids restarting the animation when multiple requested states resolve to the same clip.

Character-state triggers are resolved independently of animation lookup. Higher priority wins; updates at the same priority use the most recently updated trigger. The current CPU metric uses the metric priority, battery warnings use the system-advisory priority, system memory pressure uses the system-event priority, generic local process events and build lifecycle events share the event priority, and a manual menu selection uses the manual priority. Removing or expiring a higher-priority trigger immediately exposes the next active trigger without coupling any source to the renderer.

Battery warning changes are observed through IOKit's power-source notification run-loop source and mapped from macOS's own low-battery warning level. No warning removes the advisory trigger, early warning maps to `walk`, and final warning maps to `idle`. The system-advisory priority sits above ordinary metrics but below memory pressure so a low-battery update does not hide an urgent memory-pressure state.

System memory pressure is observed through a Dispatch memory-pressure source. Normal pressure removes the system trigger, warning maps to `dash`, and critical maps to `sprint`. The system-event priority sits above ordinary metrics but below explicit local events so CPU sampling cannot erase a pressure alert while local automation and manual overrides still remain authoritative.

Local state events are transported through macOS Distributed Notifications. The payload is a validated JSON value containing a set/clear action, a known `CharacterState`, an optional bounded TTL, and a validated channel identifier. Payloads that omit the channel remain compatible with v1 and resolve to the `default` channel. Each channel maps to an independent trigger ID and expiry timer, so clearing or expiring one automation does not remove another channel. Build lifecycle events use a separate versioned Distributed Notification payload containing only the lifecycle phase. `BuildStatePolicy` maps start to a persistent `dash` reaction, success to a 2-second `sprint`, failure to a 5-second `idle`, and cancellation to immediate removal. Both paths are local IPC rather than network services and are intended for same-user automation, not as authentication boundaries.

## 5. Asset safety

The current PoC reads the user-selected PNG directly and does not mutate it.

Imported assets are copied into a SchneeRunner-owned Application Support directory using a staging directory followed by a final directory move. Source images are never moved, renamed, overwritten, or deleted as part of import.

Each stored character uses a UUID directory and a JSON manifest. Single-image and sprite-sheet assets use `source.png`, GIF assets use `source.gif`, PNG sequences use a `frames/` directory with zero-padded frame names, and character packs use an owned `package.schneerunner/` directory containing only referenced clips in canonical paths. Character Pack export canonicalizes from that owned package into a fresh staging directory, reloads it, and refuses to replace an existing destination. A failed persistence attempt cleans up its staging directory and does not prevent the already-decoded animation from running. Image imports are inspected with ImageIO before decode; type, frame count, file size, dimensions, and pixel count must satisfy the configured validation policy. PNG sequences also enforce aggregate file-byte and decoded-pixel budgets across all frames and revalidate the owned copies before the staged directory becomes visible. GIF, APNG, and WebP animations enforce file, frame-count, per-frame dimension, and aggregate decoded-pixel limits. Owned animated-image copies are fully decoded before their staged directories are committed.

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

A transient CPU sampling failure does not terminate playback. The menu reports CPU availability and keeps the current animation speed. The CPU-derived character-state trigger is removed on sampling failure and whenever CPU adaptation is disabled, allowing the trigger engine to fall back to the next active source instead of retaining stale CPU state.

## 7. Performance direction

Menu bar playback is intentionally small.

Measure:

- frame decode time;
- retained decoded-frame memory;
- timer wakeups;
- CPU usage at each supported FPS;
- impact of one-second metric sampling.

Assets are decoded on import rather than decoded again for every displayed frame. Single-image mode renders a bounded 64-point-high working animation instead of retaining eight full-resolution copies of the source. Desktop drag and live-resize notifications are coalesced at the AppKit boundary: intermediate move/resize frames are not written to placement preferences, drag placement is persisted once on pointer release, and live resize persists its final frame once when resizing ends.

The animation timer is not restarted when a CPU sample resolves to the already-active FPS. Playback uses one-shot frame timers derived from an immutable base schedule and a separate playback-rate multiplier. Uniform frame animations use a 12 FPS reference schedule, so the existing 6 / 8 / 12 / 18 / 24 FPS controls preserve their current effective timing while authored per-frame durations can be introduced without changing the renderer.

## 8. Deferred decisions

The following remain deliberately deferred:

- Xcode project layout;
- sandboxing and entitlements;
- character-pack export and future schema versions;
- signed/notarized release configuration;
- generalized metric/event provider protocols.

Each should be introduced with its own focused change and verification path.
