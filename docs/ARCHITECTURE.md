# SchneeRunner Architecture

## 1. Goals

SchneeRunner is a local-first macOS menu bar animation engine for user-supplied character assets.

The architecture should preserve these properties:

- character artwork is data, not application-specific code;
- animation timing is independent from rendering;
- system metrics and external events are independent from animation clips;
- AppKit is kept at the application/rendering boundary;
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
                  |
                  v
          SpriteSheetGrid
```

### SchneeRunnerCore

Owns deterministic and reusable image-domain behavior:

- sprite-sheet grid validation;
- frame geometry;
- sprite-sheet decoding.

It must not own menu bar state, application lifecycle, or user interaction.

### SchneeRunnerApp

Owns macOS integration:

- application lifecycle;
- `NSStatusItem`;
- `NSOpenPanel`;
- animation scheduling;
- menu-bar image sizing;
- user-facing error presentation.

UI mutation stays on the main actor.

## 3. Planned boundaries

The target model is:

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

A future CPU provider should therefore emit a metric value rather than directly manipulating an `NSStatusItem`.

## 4. Asset safety

The current PoC reads the user-selected PNG directly and does not mutate it.

Future persistent imports should copy assets only into an explicitly SchneeRunner-owned application-support directory. Source images must never be moved, renamed, overwritten, or deleted as part of import.

Third-party character art is not part of the application distribution by default.

## 5. Failure handling

Boundary failures must become actionable errors.

Examples:

- unreadable image;
- image without decodable bitmap data;
- incompatible sprite-sheet dimensions;
- frame crop failure.

Loading a bad asset must not terminate the application or replace the last valid animation.

## 6. Performance direction

Menu bar playback is intentionally small.

Before adding richer formats or additional renderers, measure:

- frame decode time;
- retained decoded-frame memory;
- timer wakeups;
- CPU usage at each supported FPS;
- impact of metric sampling.

Assets should be decoded on import rather than decoded again for every displayed frame.

## 7. Deferred decisions

The following are deliberately not fixed by the first PoC:

- Xcode project layout;
- sandboxing and entitlements;
- persistent character-pack schema;
- GIF/APNG/WebP decoding policy;
- CPU sampling implementation;
- launch-at-login mechanism;
- signed/notarized release configuration.

Each should be introduced with its own focused change and verification path.
