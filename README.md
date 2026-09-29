# SchneeRunner

SchneeRunner is a native macOS menu bar character runner. It is designed to let users load their own character artwork and animate it locally in the menu bar.

The project does **not** bundle third-party character artwork. Imported images stay on the user's Mac.

## Status

Early proof of concept.

The first vertical slice supports:

- macOS 14+
- Swift 6 / Swift Package Manager
- native AppKit menu bar UI
- local PNG import
- 4x2 sprite sheets with 8 frames
- non-even pixel dimensions such as 1774x887
- 8 / 12 / 18 / 24 FPS playback
- no network access

CPU-based animation speed, additional image formats, character packs, persistence, and launch-at-login are intentionally deferred to later changes.

## Run locally

Requirements:

- macOS 14 or later
- a Swift 6 compatible toolchain

Run:

```bash
swift run SchneeRunner
```

SchneeRunner appears in the menu bar with a running-person placeholder icon.

Choose **Load 4x2 Sprite Sheet…** and select a PNG.

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

The initial dependency direction is:

```text
SchneeRunnerApp
      |
      v
SchneeRunnerCore
```

`SchneeRunnerCore` owns deterministic sprite-sheet geometry and decoding.
`SchneeRunnerApp` owns AppKit lifecycle, the status item, file selection, and animation scheduling.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Product direction

Planned increments:

1. CPU load -> animation speed mapping
2. persistent local character library
3. PNG sequence and GIF import
4. character states such as idle / walk / run / sprint
5. portable character-pack format
6. battery, memory, build, and local event triggers
7. optional desktop-pet renderer

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
