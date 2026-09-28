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
- persistent local character library under Application Support
- recent-character reopening from the menu
- non-even pixel dimensions such as 1774x887
- manual 6 / 8 / 12 / 18 / 24 FPS playback
- system CPU usage sampling
- exponential moving average smoothing
- hysteretic CPU-to-animation-speed mapping
- local-only operation with no network access

Additional image formats, character packs, and launch-at-login are intentionally deferred to later changes.

## Run locally

Requirements:

- macOS 14 or later
- a Swift 6 compatible toolchain

Run:

```bash
swift run SchneeRunner
```

SchneeRunner appears in the menu bar with a running-person placeholder icon.

Choose **Load Single Image…** to turn one PNG into an eight-frame procedural run cycle, or choose **Load 4x2 Sprite Sheet…** for authored animation frames.

Single-image mode renders a small normalized working copy for the menu bar and leaves the original file untouched. Successful imports are copied into SchneeRunner-owned Application Support storage so recent characters can be reopened without depending on the original file. Imports are inspected before decode and currently reject files over 32 MiB, images over 8192 pixels on either axis, images over 16 million pixels total, non-PNG content, and animated PNGs.

CPU adaptive speed is enabled by default. Selecting a manual FPS disables CPU adaptive speed until **CPU Adaptive Speed** is enabled again.

## CPU adaptive speed

SchneeRunner reads system CPU tick counters through the macOS Mach host statistics API.

The sampled utilization is smoothed with an exponential moving average before the animation pace is selected. Hysteresis prevents the animation from rapidly switching speed when CPU usage sits close to a threshold.

Current target mapping:

| Smoothed CPU utilization | Pace | FPS |
| --- | --- | ---: |
| below ~15% | idle | 6 |
| ~15–40% | walk | 8 |
| ~40–70% | run | 12 |
| ~70–90% | dash | 18 |
| ~90%+ | sprint | 24 |

Threshold transitions include a small hysteresis margin.

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

1. PNG sequence and GIF import
2. character states such as idle / walk / run / sprint
3. portable character-pack format
4. battery, memory, build, and local event triggers
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
