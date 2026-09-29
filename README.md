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
- animated GIF import with authored per-frame timing
- persistent local character library under Application Support
- recent-character reopening from the menu
- automatic restoration of the last selected character on launch
- non-even pixel dimensions such as 1774x887
- manual 0.5× / 0.67× / 1× / 1.5× / 2× playback speed
- system CPU usage sampling
- exponential moving average smoothing
- hysteretic CPU-to-animation-speed mapping
- CPU-derived idle / walk / run / dash / sprint character states
- state-aware animation lookup with deterministic default-animation fallback
- portable character-pack manifest parsing and state-specific clip loading
- local-only operation with no network access

Character-pack persistence/UI, additional animated image formats, and launch-at-login are intentionally deferred to later changes.

## Run locally

Requirements:

- macOS 14 or later
- a Swift 6 compatible toolchain

Run:

```bash
swift run SchneeRunner
```

SchneeRunner appears in the menu bar with a running-person placeholder icon.

Choose **Load Single Image…** to turn one PNG into an eight-frame procedural run cycle, **Load 4x2 Sprite Sheet…** for an authored sprite sheet, **Load PNG Sequence…** to select multiple authored frame PNGs, or **Load GIF…** to preserve an animated GIF's authored frame timing.

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

The state and playback rate are separate values. Existing single-animation assets are registered as a default **run** animation, so state changes fall back to that clip without restarting it. A future multi-state character pack can provide exact animations for idle, walk, run, dash, and sprint without changing the CPU policy or renderer.

## Character pack format

Core support exists for directory-based character packs containing `manifest.json` plus state-specific animation resources. The loader supports single PNG, 4x2 sprite sheet, PNG sequence, and GIF clips and resolves them into the same `CharacterAnimationLibrary` used by runtime state playback.

The current change is loader-only: menu import, Application Support persistence, Recent Characters, and launch restoration for packs are not wired yet.

See [docs/CHARACTER_PACK.md](docs/CHARACTER_PACK.md) for the schema and safety rules.

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

1. character-pack import, owned-copy persistence, Recent Characters, and restore
2. APNG / WebP animation import
3. battery, memory, build, and local event triggers
4. generalized trigger priority and state overrides
5. optional desktop-pet renderer

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
