# SchneeRunner Character Packs

## 1. Purpose

A character pack groups state-specific animation clips into one portable local bundle.

The first version uses a directory bundle with the extension:

```text
.schneerunnerpack
```

Archive transport can be added later without changing the manifest schema.

## 2. Bundle layout

Example:

```text
LamyRunner.schneerunnerpack/
├── manifest.json
├── idle.gif
├── walk/
│   ├── 0001.png
│   └── 0002.png
├── run.png
└── sprint.gif
```

The manifest must be located at the bundle root.

## 3. Manifest schema

Schema version 1:

```json
{
  "schemaVersion": 1,
  "name": "Example Runner",
  "defaultState": "run",
  "clips": [
    {
      "state": "idle",
      "kind": "gif",
      "path": "idle.gif"
    },
    {
      "state": "walk",
      "kind": "pngSequence",
      "path": "walk"
    },
    {
      "state": "run",
      "kind": "singleImage",
      "path": "run.png"
    },
    {
      "state": "sprint",
      "kind": "gif",
      "path": "sprint.gif"
    }
  ]
}
```

### Required fields

- `schemaVersion`: currently `1`.
- `name`: non-empty display name, up to 80 characters by default.
- `defaultState`: one of the states that has a declared clip.
- `clips`: one to five state-specific clip declarations.

## 4. States

Supported states are:

- `idle`
- `walk`
- `run`
- `dash`
- `sprint`

A state may appear at most once.

A pack does not need to implement every state. When the requested state is absent, SchneeRunner resolves to `defaultState`.

## 5. Clip kinds

### singleImage

```json
{
  "state": "run",
  "kind": "singleImage",
  "path": "run.png"
}
```

The PNG is converted into the procedural eight-frame run cycle.

### spriteSheet4x2

```json
{
  "state": "run",
  "kind": "spriteSheet4x2",
  "path": "run-sheet.png"
}
```

The clip uses the existing four-column by two-row sprite-sheet decoder.

### pngSequence

```json
{
  "state": "walk",
  "kind": "pngSequence",
  "path": "walk"
}
```

The path points to a directory containing the sequence frames. Direct children are ordered using numeric filename ordering.

### gif

```json
{
  "state": "idle",
  "kind": "gif",
  "path": "idle.gif"
}
```

Authored GIF frame durations are preserved and the normal GIF resource limits apply.

## 6. Path rules

Clip paths are relative to the pack root.

The loader rejects:

- absolute paths;
- empty path components;
- `.` and `..` components;
- backslashes;
- colon-based drive-style paths;
- symbolic links anywhere inside the bundle.

These rules prevent a manifest from escaping the selected pack directory.

## 7. Resource limits

Default pack-wide limits:

- maximum total file bytes: 128 MiB;
- maximum file count: 650;
- maximum display-name length: 80 characters;
- maximum clips: five.

Each referenced clip must also satisfy the existing validation policy for its own format.

For example, a GIF must still satisfy GIF frame, dimension, byte, and decoded-pixel limits.

## 8. Persistence

Import follows the same staged-copy model as other SchneeRunner assets:

```text
selected pack
    |
    v
validate + decode
    |
    v
Application Support staging directory
    |
    v
copy pack
    |
    v
validate + decode owned copy
    |
    v
atomic directory move into character library
```

The original bundle is never moved, renamed, overwritten, or deleted.

The stored asset has an outer SchneeRunner character manifest and an owned inner bundle:

```text
Characters/<UUID>/
├── manifest.json
└── pack.schneerunnerpack/
    ├── manifest.json
    └── ...
```

## 9. State resolution

CPU adaptive mode maps the current CPU pace to a character state.

The playback pipeline is:

```text
CPU pace
   |
   v
CharacterState
   |
   v
CharacterAnimationLibrary
   |
   +--> exact state clip
   |
   +--> default-state fallback
   |
   v
AnimationController
```

Changing between states that resolve to the same fallback clip does not restart playback.
