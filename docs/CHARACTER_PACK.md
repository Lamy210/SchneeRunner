# SchneeRunner Character Pack v1

A SchneeRunner character pack is a directory whose name ends in `.schneerunner`.

The format is intentionally directory-based in v1 so it can be created, inspected, versioned, and validated without archive dependencies.

## Layout

Example:

```text
LamyStyle.schneerunner/
├── character.json
├── idle.gif
└── run/
    ├── frame1.png
    ├── frame2.png
    └── frame3.png
```

Only files referenced by `character.json` are imported. Unreferenced files are not copied into SchneeRunner's local character library.

## Manifest

`character.json`:

```json
{
  "formatVersion": 1,
  "name": "Example Runner",
  "defaultState": "run",
  "clips": [
    {
      "state": "idle",
      "kind": "gif",
      "path": "idle.gif"
    },
    {
      "state": "run",
      "kind": "pngSequence",
      "path": "run"
    }
  ]
}
```

Required fields:

- `formatVersion`: currently `1`
- `name`: 1–80 non-whitespace characters
- `defaultState`: one of `idle`, `walk`, `run`, `dash`, or `sprint`
- `clips`: one to five state-specific animation clips

A state may appear at most once. The default state must have a clip.

## Clip kinds

### `singleImage`

`path` points to one static PNG. SchneeRunner generates the normal procedural eight-frame run cycle from that image.

### `spriteSheet4x2`

`path` points to one static PNG containing eight frames in the standard four-column, two-row layout.

### `gif`

`path` points to one animated GIF.

The normal GIF safety policy applies, including file-size, frame-count, dimension, decoded-pixel, and frame-duration limits.

### `apng`

`path` points to one animated PNG. The normal APNG safety policy and authored frame timing apply.

### `webP`

`path` points to one animated WebP file. The normal WebP safety policy and authored frame timing apply.

### `pngSequence`

`path` points to a directory containing the sequence PNGs.

The normal PNG Sequence policy applies. Frames use numeric filename ordering, must have identical dimensions, and must satisfy per-frame and aggregate resource limits.

## State fallback

A pack does not need to provide all five states.

When the requested state is unavailable, SchneeRunner resolves to the manifest's `defaultState` clip. This allows a two-state pack such as `idle + run` to work immediately while richer packs can provide all states.

## Import and persistence

Imported packs are rewritten into a canonical owned copy:

```text
Characters/<uuid>/
├── manifest.json
└── package.schneerunner/
    ├── character.json
    └── clips/
        ├── idle/
        │   └── source.gif
        └── run/
            └── frames/
                ├── 0001.png
                ├── 0002.png
                └── ...
```

The original package is never moved, renamed, overwritten, or deleted.

The owned copy is fully reloaded before its staging directory is committed.

## Building packs programmatically

`CharacterPackBuilder` creates a canonical v1 pack from local clip sources. A build request supplies the pack name, default state, and one source per state.

Source semantics match the manifest clip kinds:

- `singleImage` and `spriteSheet4x2` point to PNG files;
- `gif` points to one GIF file;
- `apng` points to one animated PNG file;
- `webP` points to one animated WebP file;
- `pngSequence` points to a directory containing the PNG frames.

The builder validates name/state rules before copying, normalizes clip order to `idle`, `walk`, `run`, `dash`, `sprint`, applies the normal aggregate package-size limit, writes into a temporary `.schneerunner` directory, reloads the completed package, and only then moves it to the requested destination.

Builds reject symlink clip files, invalid clip data, duplicate states, a missing default-state clip, non-`.schneerunner` destinations, and existing destinations. Failed builds remove their staging directory and leave source files unchanged.

## Builder UI

**Build Character Pack…** opens the in-app builder.

The builder lets the user:

- enter the Character Pack name;
- choose the default state;
- optionally attach one clip to each of idle, walk, run, dash, and sprint;
- choose `singleImage`, `spriteSheet4x2`, `pngSequence`, `gif`, `apng`, or `webP` independently per state;
- clear or replace an already selected clip source;
- choose the final `.schneerunner` destination only after the draft is complete.

Changing a row's clip kind clears its previously selected source so stale files cannot be reinterpreted as a different clip type. The selected default state must have a clip. The UI delegates final validation and canonical package creation to `CharacterPackBuilder`.

Building a package is side-effect free with respect to playback: it does not replace the currently running character or change CPU-adaptive state.

## Export

A currently loaded, stored Character Pack can be written back out with **Export Current Character Pack…**.

Export does not recursively copy the owned package directory. SchneeRunner reads the stored manifest, copies only referenced clips into a fresh canonical staging package, writes a new canonical manifest, reloads the staged package, and only then moves it to the selected destination.

Export rules:

- the destination must end in `.schneerunner`;
- an existing file or directory is never overwritten;
- unreferenced files added to the owned package are not exported;
- canonical clip names and ordering are regenerated;
- the exported package must pass the same loader and aggregate resource limits as an imported pack.

## Security rules

Character Pack v1 rejects:

- package directories without the `.schneerunner` extension;
- package or clip symlinks, including symlinked intermediate path components;
- absolute clip paths;
- `.` and `..` path components;
- backslash-based paths;
- missing or oversized manifests;
- duplicate states;
- missing default-state clips;
- invalid GIF or PNG Sequence resources;
- aggregate referenced clip data above 128 MiB;
- more than 240 decoded frames across the pack;
- more than 32 million decoded pixels across all state clips.

Only manifest-referenced clip files are copied. Extra files in the source package are ignored.

## Compatibility

Character Pack v1 supports `singleImage`, `spriteSheet4x2`, `pngSequence`, `gif`, `apng`, and `webP` clips.

Unknown format versions or clip kinds are rejected rather than guessed.
