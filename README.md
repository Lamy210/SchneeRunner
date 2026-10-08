# SchneeRunner

SchneeRunner is a native macOS menu bar character runner. It can animate the bundled default character or user-provided character artwork locally in the menu bar and optional desktop renderer.

The packaged application includes a generated, unofficial fan-made Yukihana Lamy walk-cycle as its default demo character. A previously selected local character always takes priority over the bundled fallback. Imported images stay on the user's Mac.

SchneeRunner is an **unofficial fan-made project** and is not affiliated with or endorsed by **COVER Corp.** or hololive production. Yukihana Lamy and related names and characters belong to their respective rights holders. The bundled walk-cycle artwork is generated fan-made artwork, not official artwork.

## Download

[**Download latest release**](https://github.com/Lamy210/SchneeRunner/releases/latest)

Requirements: **macOS 14 or later**.

1. Download the DMG from the latest GitHub Release.
2. Open the DMG and move **SchneeRunner.app** to **Applications**.
3. Launch SchneeRunner from Applications.

**Do not use v0.1.0.** It was an early **unsigned** and **not notarized** build, and macOS can report that quarantined copy as damaged or unable to open.

**v0.1.1 is intentionally published unsigned and not notarized.** Before publication, the release pipeline still verifies the DMG structure, bundled application executable, bundled four-frame default character, SHA-256 checksum, release provenance, and trusted source binding. Because the app is not Developer ID signed or Apple-notarized, macOS Gatekeeper may still report a downloaded or quarantined copy as **damaged** or refuse to open it. Developer ID signing and Apple notarization are required to remove that trust warning reliably; DMG integrity verification alone cannot replace those trust checks.

## Status

Early proof of concept.

The current vertical slice supports:

- macOS 14+
- Swift 6 / Swift Package Manager
- native AppKit menu bar UI
- bundled four-frame default walk cycle when no saved character is available
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
- restart-safe concurrent countdown timers with preset and custom durations
- configurable Pomodoro focus / short-break / long-break sessions
- one-shot, daily, and weekday reminders with snooze and local notifications
- bounded local productivity history and optional character reactions
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

Single-image mode renders a small normalized working copy for the menu bar and leaves the original file untouched. The generated eight-frame cycle combines lift, tilt, squash, and stretch transforms around a foot-style anchor. Successful imports are copied into SchneeRunner-owned Application Support storage so recent characters can be reopened without depending on the original file. The last successfully selected stored character is restored automatically on the next launch. If that stored selection can no longer be loaded, SchneeRunner clears the saved selection, quarantines the unavailable asset from Recent Characters for the current app session, and continues launching with the bundled default character when that resource is available. A Recent Character that fails when selected is quarantined the same way without deleting its stored files. Quarantined entries do not consume Recent Characters slots; older available assets fill the menu up to its normal limit. Recent Characters performs a filesystem-only structural preflight of SchneeRunner-owned backing paths whenever the status menu opens, including Character Pack manifest references, clip resource types, and PNG Sequence directory structure, so entries that become missing, symlinked, or structurally mismatched during the current session are omitted before the menu limit without decoding media or deleting stored data. Imports are inspected before decode and currently reject files over 32 MiB, images over 8192 pixels on either axis, images over 16 million pixels total, non-PNG content, and animated PNGs.

CPU adaptive speed is enabled by default. Selecting a manual playback rate disables CPU adaptive speed until **CPU Adaptive Speed** is enabled again. Disabling CPU adaptation clears the CPU-derived character-state trigger, and a CPU sampling error clears it as well, so stale CPU state does not remain active while other state triggers continue to resolve normally. The rate scales the animation's base timing, so GIF frame-duration ratios remain intact.

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

## Productivity timers, Pomodoro, and reminders

SchneeRunner includes local productivity tools in the status menu and a dedicated management window. Multiple countdown timers can run concurrently, Pomodoro sessions support configurable focus / short-break / long-break durations and auto-start behavior, and reminders support one-shot, daily, and selected-weekday schedules with snooze actions.

Running countdowns and Pomodoro phases are **deadline-authoritative**. Their persisted deadline is the source of truth; the in-process one-second refresh loop only updates presentation. Restart, sleep, delayed run-loop delivery, and wall-clock changes therefore recompute state from the persisted deadline instead of accumulated ticks. Startup reconciliation is idempotent so an overdue timer or Pomodoro phase is completed or advanced once before regular refresh loops begin.

Productivity state is stored locally under `Application Support/SchneeRunner/Productivity/`. `state.json` contains the versioned timer, Pomodoro, reminder, and snooze snapshot. `history.json` stores bounded productivity history and retains the newest 500 entries. Character-reaction enablement is a separate `UserDefaults` preference and defaults to enabled.

Local notifications are reconciled by stable identifiers owned by SchneeRunner. Timer requests use `schneerunner.timer.`, Pomodoro requests use `schneerunner.pomodoro.`, reminder requests use `schneerunner.reminder.`, and snooze requests use `schneerunner.snooze.`. Reconciliation removes or replaces only requests under those owned prefixes; unrelated pending notifications are preserved. If notification permission is denied, timer/Pomodoro/reminder domain state continues to work and the UI reports the disabled notification path rather than treating notification delivery as the source of truth.

When **Productivity Character Reactions** is enabled, productivity activity is aggregated into one `.event`-priority `productivity` trigger. Its internal precedence is reminder fired > timer completed > final minute > Pomodoro focus > active countdown > break. Reminder/completion reactions are short-lived and schedule their own expiry, so they clear even when no timer or Pomodoro refresh loop is running. Manual character-state overrides remain stronger than productivity updates. Disabling the toggle immediately removes the productivity trigger without changing timer, Pomodoro, or reminder state.

## Desktop character renderer

The **Desktop Character** submenu can show the currently resolved animation in an optional transparent desktop window. The window is off by default, floats above normal windows, joins all Spaces, and can be repositioned by dragging the character. Its edges are resizable from 64 to 512 points while preserving a square presentation area.

Desktop position and size are persisted locally and restored on the next launch. If a saved frame no longer intersects any connected display, SchneeRunner ignores that frame and falls back to its normal on-screen starting position; partially visible frames are clamped back into the selected display's visible area. While the app is running, display-topology and visible-frame changes also recover an existing desktop window onto a connected display and persist the recovered frame. The **Show on Desktop** choice is also persisted and restored on launch. Automatic movement intentionally starts disabled after each launch and must be enabled explicitly from the menu.

The submenu also offers **Move Automatically** while the desktop character is visible. Autonomous movement advances horizontally and reflects at the current display's visible edges. If the user drags or resizes the desktop character while automatic movement is enabled, autonomous position updates pause for the pointer interaction, persist the user-selected frame once at interaction end, and resume from that frame. The motion loop also reconciles interaction state against the current primary-button state so a missed mouse-up cannot leave autonomous movement paused indefinitely. The desktop presentation mirrors horizontally when the motion direction changes and returns to the source orientation when automatic movement stops, while the menu bar image and stored character assets remain unchanged. Its deterministic motion policy is independent from CharacterState, CPU load, animation playback rate, and Character Pack state selection.

**Click Through** makes the desktop character ignore mouse input so clicks reach applications behind it. The setting is persisted and restored on launch. While Click Through is enabled, the desktop character cannot be dragged or resized directly; use the menu-bar item to disable Click Through before repositioning it.

**Reset Position & Size** restores the desktop character to the default 128-point square near the lower-right of the current main display and persists that placement. The reset remains available while the desktop character is hidden or Click Through is enabled. If autonomous movement is active, it continues from the reset position instead of being disabled.

Timer delays are capped before they reach the motion policy so a delayed wakeup cannot teleport the character across the desktop. The **Movement Speed** submenu provides **Slow (36 pt/s)**, **Normal (72 pt/s)**, and **Fast (120 pt/s)** presets; Normal preserves the original autonomous-movement speed. The selected preset is persisted locally and restored on the next launch. Speed changes affect only desktop motion and apply while movement is already running. Programmatic movement does not write placement preferences on every frame; user drags persist once when the interaction ends, and the final automatic position is persisted when automatic movement stops or SchneeRunner terminates.

The desktop renderer receives the same decoded animation frames as the menu bar renderer. It does not load character assets independently and does not alter trigger resolution, playback timing, or Character Pack behavior. Closing SchneeRunner tears down the desktop window with the rest of the application lifecycle.

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

Each channel owns an independent trigger and TTL timer. Expiring or clearing one channel therefore exposes the next active trigger instead of deleting unrelated local automation. Multiple local channels and build lifecycle events share the explicit event priority; the existing recency rule selects the most recently updated active trigger. The current priority order is **manual > local event/build event/productivity > system memory pressure > battery warning > CPU metric**. Sources that share event priority resolve by the trigger engine's existing most-recent-update rule.

The control path uses macOS Distributed Notifications and does not open a network port. It is intended for same-user local automation such as build scripts and development hooks; it is not an authenticated security boundary. Malformed payloads are ignored.

## Memory pressure trigger

SchneeRunner monitors macOS system memory-pressure transitions locally. Normal pressure does not install a trigger. A warning requests the **dash** state, while critical pressure requests **sprint**. Returning to normal removes the memory-pressure trigger and immediately exposes the next active source.

The priority order is **manual > local event/build event/productivity > system memory pressure > battery warning > CPU metric**. This keeps an explicit user override strongest, lets explicit event-driven behavior override system pressure when needed, and prevents the one-second CPU sampler from immediately replacing a pressure alert.

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

When the current stored character is a Character Pack, **Export Current Character Pack…** writes a fresh canonical `.schneerunner` directory. Export reuses only manifest-referenced clips, reloads the staged result before commit, and refuses to replace an existing destination.

Choose **Build Character Pack…** to set a pack name and default state, attach optional idle / walk / run / dash / sprint clips, and write a canonical `.schneerunner` package. PNG Sequence clips select a source directory; single-image and sprite-sheet clips select PNG files, GIF clips select GIF files, APNG clips select animated PNG files, and WebP clips select animated WebP files. Building a pack does not change the currently running character.

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

`SchneeRunnerCore` owns deterministic sprite-sheet geometry, procedural single-image frame generation, character-state policy, productivity timer/Pomodoro/reminder domain rules, versioned productivity snapshots/history, CPU utilization calculation, smoothing, and animation-speed policy.

`SchneeRunnerApp` owns AppKit lifecycle, the status item, file selection, Mach CPU sampling, run-loop refresh timers, local productivity persistence, `UserNotifications` integration, and user-facing state.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Product direction

The current desktop-renderer vertical slice now includes persistent placement and visibility, placement reset, autonomous horizontal movement, direction-aware presentation, independent movement-speed presets, runtime display recovery, and optional click-through interaction.

The engine should keep character assets, animation clips, triggers, metrics, productivity state, and renderers independent so future render targets or productivity surfaces do not require rewriting the core model.

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