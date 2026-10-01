# SchneeRunner

SchneeRunner is a native macOS menu bar character runner. It is designed to let users load their own character artwork and animate it locally in the menu bar.

The project does **not** bundle third-party character artwork. Imported images stay on the user's Mac.

## Status

Early proof of concept.

The current vertical slice supports:

- macOS 14+
- Swift 6 / Swift Package Manager
- native AppKit menu bar UI
- local PNG import with pre-decode size/type validation
- single-image procedural run animation
- 4x2 sprite sheets with 8 frames
- ordered multi-file PNG sequences
- animated GIF, APNG, and WebP import with authored per-frame timing
- persistent local character library under Application Support
- recent-character reopening from the menu
- automatic restoration of the last selected character on launch
- non-even pixel dimensions such as 1774x887
- manual 0.5× / 0.67× / 1× / 1.5× / 2× playback speed
- system CPU usage sampling
- exponential moving average smoothing
- hysteretic CPU-to-animation-speed mapping
- CPU-derived idle / walk / run / dash / sprint character states
- priority-aware character-state trigger resolution
- manual Automatic / Idle / Walk / Run / Dash / Sprint state override
- local state-event CLI with optional TTL expiry
- system memory-pressure trigger with warning / critical escalation
- system low-battery warning trigger driven by macOS warning levels
- first-class local build lifecycle trigger for start / success / failure / cancel
- state-aware animation lookup with deterministic default-animation fallback
- portable `.schneerunner` character packs with state-specific PNG, sprite-sheet, PNG Sequence, and GIF clips
- canonical export of the currently loaded stored Character Pack
- Core Character Pack builder for assembling canonical packs from local clips
- in-app Character Pack builder with per-state clip selection
- system-managed Launch at Login
- local-only operation with no network access

Additional character-pack clip kinds, additional animated image formats, and export tooling are intentionally deferred to later changes.

## Run locally

Requirements:

- macOS 14 or later
- a Swift 6 compatible toolchain

Run:

```bash
swift run SchneeRunner
```

SchneeRunner appears in the menu bar with a running-person placeholder icon.

The **Launch at Login** menu item uses macOS system-managed login-item registration for the packaged application. If macOS requires user approval, SchneeRunner shows **Approval Required** and opens System Settings > Login Items when selected. The menu refreshes from the system registration status each time it opens rather than storing a separate preference.

Choose **Load Single Image…** to turn one PNG into an eight-frame procedural run cycle, **Load 4x2 Sprite Sheet…** for an authored sprite sheet, **Load PNG Sequence…** for multiple PNG frames, or **Load GIF…**, **Load APNG…**, and **Load WebP…** to preserve authored per-frame timing.

Single-image mode renders a small normalized working copy for the menu bar and leaves the original file untouched. The generated eight-frame cycle combines lift, tilt, squash, and stretch transforms around a foot-style anchor. Successful imports are copied into SchneeRunner-owned Application Support storage so recent characters can be reopened without depending on the original file. The last successfully selected stored character is restored automatically on the next launch. If that stored selection can no longer be loaded, SchneeRunner clears the saved selection and continues launching with the placeholder. Imports are inspected before decode and currently reject files over 32 MiB, images over 8192 pixels on either axis, images over 16 million pixels total, non-PNG content, and animated PNGs.

CPU adaptive speed is enabled by default. Selecting a manual playback rate disables CPU adaptive speed until **CPU Adaptive Speed** is enabled again. The rate scales the animation's base timing, so GIF frame-duration ratios remain intact.

## CPU adaptive speed

SchneeRunner reads system CPU tick counters through the macOS Mach host statistics API.

The sampled utilization is smoothed with an exponential moving average before the animation pace is selected. Hysteresis prevents the animation from rapidly switching speed when CPU usage sits close to a threshold.

Current target mapping:

| Smoothed CPU utilization | Character state | Playback rate |
| --- | --- | ---: |
| below ~15% | idle | 0.5× |
| ~15–40% | walk | 0.67× |
| ~40–70% | run | 1× |
| ~70–90% | dash | 1.5× |
| ~90%+ | sprint | 2× |

Threshold transitions include a small hysteresis margin.

The state and playback rate are separate values. CPU state updates are registered as low-priority metric triggers. Local events use the middle event priority, and the **Character State** submenu uses the highest manual priority. Returning the menu to **Automatic** removes only the manual override and immediately resolves the next available trigger. Existing single-animation assets are registered as a default **run** animation, so state changes fall back to that clip without restarting it. Character packs can provide exact animations for idle, walk, run, dash, and sprint without changing the trigger policy or renderer.

## Local state events

With SchneeRunner running, local scripts can temporarily or persistently request one of the existing character states:

```bash
swift run schneerunnerctl state sprint --seconds 5
swift run schneerunnerctl state idle
swift run schneerunnerctl clear
```

Independent automations can use named channels so one script does not overwrite or clear another script's trigger:

```bash
swift run schneerunnerctl state dash --channel build-a
swift run schneerunnerctl state sprint --seconds 10 --channel test-suite
swift run schneerunnerctl clear --channel build-a
```

The channel defaults to `default` for backward compatibility. Channel names are 1–64 bytes and accept letters, numbers, `.`, `_`, and `-`. Older v1 payloads without a channel still decode into the default channel.

Each channel owns an independent trigger and TTL timer. Expiring or clearing one channel therefore exposes the next active trigger instead of deleting unrelated local automation. Multiple local channels and build lifecycle events share the explicit event priority; the existing recency rule selects the most recently updated active trigger. The current priority order is **manual > local event/build event > system memory pressure > battery warning > CPU metric**.

The control path uses macOS Distributed Notifications and does not open a network port. It is intended for same-user local automation such as build scripts and development hooks; it is not an authenticated security boundary. Malformed payloads are ignored.

## Memory pressure trigger

SchneeRunner monitors macOS system memory-pressure transitions locally. Normal pressure does not install a trigger. A warning requests the **dash** state, while critical pressure requests **sprint**. Returning to normal removes the memory-pressure trigger and immediately exposes the next active source.

The priority order is **manual > local event/build event > system memory pressure > battery warning > CPU metric**. This keeps an explicit user override strongest, lets local automation override system pressure when needed, and prevents the one-second CPU sampler from immediately replacing a pressure alert.

## Battery warning trigger

SchneeRunner listens for macOS power-source changes and reads the operating system's low-battery warning level. It does not define its own battery-percentage thresholds. No warning removes the battery trigger, an early warning requests **walk**, and a final warning requests **idle**.

Battery warnings use a system-advisory priority below memory pressure and above the CPU metric. A critical memory-pressure state therefore remains authoritative over a later battery update, while CPU sampling cannot immediately erase the battery warning. Desktops and Macs on external power resolve to the no-warning path.

## Build lifecycle trigger

Build scripts can report lifecycle events without choosing animation states themselves:

```bash
swift run schneerunnerctl build start
swift run schneerunnerctl build success
swift run schneerunnerctl build failure
swift run schneerunnerctl build cancel
```

A started build requests **dash** until another build lifecycle event arrives. Success requests **sprint** for 2 seconds, failure requests **idle** for 5 seconds, and cancel removes the build trigger immediately. Terminal reactions expire automatically and expose the next active trigger.

The build event uses the same local Distributed Notification transport as manual local automation, but has its own versioned payload and notification name. It opens no network port and needs no GitHub token. Generic local-state events and build events share the explicit local-event priority, so whichever source updated most recently wins until it clears or expires.

A shell integration can report a complete build without coupling the script to character states:

```bash
swift run schneerunnerctl build start
if swift build; then
  swift run schneerunnerctl build success
else
  status=$?
  swift run schneerunnerctl build failure
  exit "$status"
fi
```

## Character Pack v1

Choose **Load Character Pack…** to import a directory ending in `.schneerunner`. A pack can provide separate clips for idle, walk, run, dash, and sprint. Missing states fall back to the pack's declared default state.

Character Pack v1 accepts single-image PNG, 4x2 sprite sheet, PNG Sequence, GIF, APNG, and WebP clips. Only manifest-referenced assets are copied into SchneeRunner's local library; paths using `..`, absolute paths, backslashes, or symlinks are rejected. Imported packs are rewritten into a canonical owned layout and fully reloaded before the staged copy becomes visible. A pack is capped at 240 decoded frames and 32 million decoded pixels across all state clips.

When the current stored character is a Character Pack, **Export Current Character Pack…** writes a fresh canonical `.schneerunner` directory. Export reuses only manifest-referenced clips, reloads the staged result before commit, and refuses to overwrite an existing destination.

Choose **Build Character Pack…** to set a pack name and default state, attach optional idle / walk / run / dash / sprint clips, and write a canonical `.schneerunner` package. PNG Sequence clips select a source directory; the other clip kinds select PNG or GIF files. Building a pack does not change the currently running character.

See [docs/CHARACTER_PACK.md](docs/CHARACTER_PACK.md) for the manifest and layout specification.

## APNG and WebP formats

APNG and animated WebP imports use the same bounded animation policy as GIF: 2–120 frames, a 32 MiB file limit, a 4096-pixel limit on either axis, and 16 million decoded pixels across the animation. Per-frame delays are preserved and delays below 20 ms are clamped to reduce excessive timer wakeups.

APNG accepts animated PNG data selected through either a `.png` or `.apng` filename. WebP accepts animated `.webp` data. File extensions are only picker hints; ImageIO content type and frame count are validated before decode. Owned copies are fully decoded again before staged persistence is committed, and both formats participate in Recent Characters and last-character restoration.

Character Pack v1 also accepts `apng` and `webP` clips. They use the same bounded animated-image validation and authored frame timing as standalone imports.

## GIF format

GIF mode accepts animated GIFs with 2–120 frames. Authored frame delays are preserved, with extremely short delays clamped to 20 ms to avoid excessive timer wakeups.

GIF imports are limited to 32 MiB, 4096 pixels on either axis, and 16 million decoded pixels across the animation. Every frame's metadata is validated before decode, and the owned copy is fully decoded before its staged character directory is committed. The original GIF remains untouched; the owned copy participates in Recent Characters and last-character restoration.

## PNG sequence format

PNG Sequence mode accepts 2–120 static PNG files. Frames are sorted by file name using numeric ordering, so names such as `frame2.png` are placed before `frame10.png`.

All sequence frames must have identical pixel dimensions and pass the normal image-import safety limits. A sequence is additionally capped at 64 MiB of source data and 16 million decoded pixels in total. Stored sequences are copied into SchneeRunner-owned `frames/0001.png`, `0002.png`, and so on; the original files remain untouched. Stored sequences participate in Recent Characters and last-character restoration just like single-image and sprite-sheet assets.

## Sprite sheet format

The current PoC expects exactly eight frames arranged like this:

```text
+---------+---------+---------+---------+
| frame 1 | frame 2 | frame 3 | frame 4 |
+---------+---------+---------+---------+
| frame 5 | frame 6 | frame 7 | frame 8 |
+---------+---------+---------+---------+
```

Requirements:

- PNG
- four columns and two rows
- transparent backgrounds are recommended
- keep the character scale and ground baseline consistent between frames

The image does not need to be evenly divisible by four columns and two rows. SchneeRunner partitions the full pixel extent proportionally, so adjacent cells may differ by one pixel while no source pixels are dropped.

Frame order is top row left-to-right, then bottom row left-to-right.

## Architecture

The dependency direction is:

```text
SchneeRunnerApp
      |
      v
SchneeRunnerCore
```

`SchneeRunnerCore` owns deterministic sprite-sheet geometry, procedural single-image frame generation, CPU utilization calculation, smoothing, and animation-speed policy.

`SchneeRunnerApp` owns AppKit lifecycle, the status item, file selection, Mach CPU sampling, timers, and user-facing state.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Product direction

Planned increments:

1. optional desktop-pet renderer

The engine should keep character assets, animation clips, triggers, metrics, and renderers independent so future render targets do not require rewriting the core model.

## Development

Follow:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md)
- [docs/BRANCHING.md](docs/BRANCHING.md)
- [docs/QUALITY.md](docs/QUALITY.md)

Feature work uses short-lived branches and pull requests. Squash merge is preferred.

## Privacy and asset policy

SchneeRunner's core experience is local-first.

The application should not upload imported artwork or telemetry by default. Character artwork from third parties must not be added to the public repository unless its redistribution terms explicitly allow that use.
