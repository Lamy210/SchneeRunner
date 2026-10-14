# App Sandbox

SchneeRunner's signed macOS distribution enables App Sandbox through the checked-in `SchneeRunner.entitlements` file.

## Capability policy

The production entitlement set is intentionally minimal:

- `com.apple.security.app-sandbox = true`
- `com.apple.security.files.user-selected.read-write = true`

No network entitlement, temporary exception, or broad Downloads/Documents/user-home file entitlement is granted.

The user-selected file entitlement matches the existing import/export boundary: character imports are chosen with `NSOpenPanel`, and Character Pack exports are chosen with a save panel. Imported assets are copied into SchneeRunner-owned Application Support storage instead of retaining ambient access to their original locations.

Application-owned persistence remains under the user's Application Support domain. When App Sandbox is active, macOS resolves that domain inside SchneeRunner's application container; no entitlement for arbitrary Application Support access is required.

## Local IPC

Character-state and build-lifecycle automation continue to use `DistributedNotificationCenter`. The CLI encodes its validated payload into the notification `object` and sends `userInfo: nil`; the app decodes that object. Do not move this protocol to a `userInfo` dictionary without re-evaluating App Sandbox compatibility.

These notifications are a same-user local automation channel, not an authentication boundary.

## Release and CI enforcement

The unsigned release-build artifact remains entitlement-free until the privileged signing stage. The trusted default-branch publisher passes `SchneeRunner.entitlements` to `reusable-macos-release.yml`, which applies it during Developer ID signing.

Normal pull-request CI exercises the same capability set without Apple credentials:

1. build the packaged `.app`;
2. ad-hoc sign it with `SchneeRunner.entitlements`;
3. verify the code signature;
4. extract the embedded entitlements and require both approved keys to be `true`;
5. launch-smoke the sandboxed `.app`.

The release contract test also parses `SchneeRunner.entitlements` and requires the plist to equal the two-key capability set above. Adding another entitlement therefore requires an explicit, reviewed contract change rather than silently widening the sandbox.

## Change policy

Treat entitlement changes as security-boundary changes. Any additional capability must have a concrete feature requirement, a least-privilege justification, and a CI verification path. In particular, do not add network or temporary-exception entitlements merely to bypass a failing smoke test; first identify the exact sandbox denial and the owning feature boundary.
