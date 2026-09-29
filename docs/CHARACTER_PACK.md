# Character Pack Format

## 1. Status

Schema version 1 defines a directory-based character pack for SchneeRunner Core.

The recommended directory suffix is `.schneerunner`, but the Core loader validates content rather than relying on the suffix.

UI import and persistent owned-copy storage are intentionally separate follow-up work.

## 2. Layout

A pack contains `manifest.json` at its root and animation resources referenced by relative path.

```text
Sample.schneerunner/
├── manifest.json
└── animations/
    ├── idle.gif
    └── run/
        ├── frame1.png
        └── frame2.png
```

## 3. Manifest schema

Example:

```json
{
  "schemaVersion": 1,
  "name": "Sample Runner",
  "defaultState": "run",
  "animations": [
    {
      "state": "idle",
      "kind": "gif",
      "path": "animations/idle.gif"
    },
    {
      "state": "run",
      "kind": "pngSequence",
      "path": "animations/run"
    }
  ]
}
```

Supported states:

- `idle`
- `walk`
- `run`
- `dash`
- `sprint`

Supported animation kinds:

- `singleImage` — one PNG transformed into the procedural run cycle;
- `spriteSheet4x2` — one authored 4x2 PNG sprite sheet;
- `pngSequence` — a directory containing PNG frame files;
- `gif` — an animated GIF with authored frame durations.

`defaultState` must reference one animation present in the manifest. If runtime requests a state the pack does not provide, `CharacterAnimationLibrary` resolves to the default state.

## 4. Safety rules

Schema version 1 applies these pack-level limits:

- manifest size: at most 64 KiB;
- pack name: non-empty, at most 80 characters, no control characters;
- animation count: at most five, matching the current character-state count;
- duplicate state entries: rejected;
- referenced paths: relative only;
- empty, `.`, and `..` path components: rejected;
- symlinks: rejected at every referenced path component;
- aggregate loaded-frame budget: at most 32 million pixels across all state clips.

Each referenced resource also passes its existing format-specific validation. For example, GIF and PNG-sequence frame count, dimensions, file sizes, and decoded-pixel budgets remain enforced.

## 5. Trust boundary

The manifest is data, not executable configuration.

The loader does not:

- execute scripts;
- resolve network URLs;
- expand home-directory shortcuts;
- follow symlinks;
- allow paths to escape the selected pack root.

Unknown JSON fields are ignored by Swift decoding, while unknown enum values or malformed required fields cause manifest decoding to fail.

## 6. Next integration step

The application layer still needs to:

1. expose **Load Character Pack…** in the menu;
2. copy validated pack content into SchneeRunner-owned Application Support storage;
3. represent the stored pack in Recent Characters;
4. restore the selected pack on launch;
5. preserve a migration boundary for future schema versions.
