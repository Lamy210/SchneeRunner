# Runtime Parity and Japanese Localization Design

Date: 2026-10-09
Status: Proposed

## Context

SchneeRunner currently has three materially different runtime environments:

1. `swift run SchneeRunner` / SwiftPM bare executable
2. the unsigned packaged `.app` used inside the public DMG
3. a fully bundled macOS application runtime

The current notification safety fix intentionally disables UserNotifications when the process is not a valid `.app` bundle, and the unsigned public release additionally writes `SchneeRunnerSystemNotificationsEnabled=false` into `Info.plist`. This prevented the startup crash discovered in v0.1.1/v0.1.2, but it also means Timer, Pomodoro, and Reminder lose their system-notification delivery path in the exact environments currently used for development and public unsigned distribution.

The user has explicitly decided that SchneeRunner will **not use Developer ID signing or Apple notarization**. The product must therefore work usefully under an unsigned distribution model rather than treating Developer ID as a future prerequisite.

At the same time, the UI is currently English-only and most visible strings are hard-coded directly into AppKit controllers and Core display-name helpers. Japanese support is required.

## Goals

1. Keep the application useful when UserNotifications are unavailable.
2. Make `swift run SchneeRunner` useful for normal development and feature testing.
3. Keep the unsigned packaged app launch-safe.
4. Make Timer, Pomodoro, and Reminder behavior explicit and predictable across runtimes.
5. Add English and Japanese UI localization using the macOS language setting.
6. Preserve existing persisted state, file formats, notification identifiers, character-pack schemas, and CLI protocols.
7. Add end-to-end regression coverage for the actual user paths that previously escaped CI.

## Non-goals

- Developer ID signing
- Apple notarization
- bypassing or weakening Gatekeeper
- a custom in-app language selector in the first localization pass
- changing Character Pack schema
- changing persisted enum raw values
- replacing the existing timer/pomodoro/reminder domain model
- making reminders fire while SchneeRunner is not running when system notifications are unavailable

## Product behavior

### Runtime capabilities

Introduce one app-layer runtime capability model. It must answer, at minimum:

- whether system notifications are available
- whether Launch at Login is available
- whether bundled application resources are available
- whether an in-process fallback notifier is available

The capability model is derived from runtime facts such as bundle identifier, bundle URL, Info.plist opt-ins, and application packaging. Controllers must consume this capability model rather than each independently guessing whether the process is packaged.

Core domain models remain runtime-agnostic.

### Notification policy

System UserNotifications remain guarded by the existing launch-safety policy. Do **not** simply change `SchneeRunnerSystemNotificationsEnabled` to `true` in unsigned builds.

Delivery policy becomes:

1. If system notifications are available and enabled, use the current `UNUserNotificationCenter` scheduler.
2. If system notifications are unavailable but the application is running, use an in-process fallback notifier.
3. Domain state changes must succeed regardless of delivery backend availability.

The fallback notifier provides an AppKit-visible notification while the app is alive. The first implementation should use an app-owned alert/presentation abstraction plus a system sound rather than attempting to emulate `UNUserNotificationCenter`.

The fallback path must be injectable and testable. Domain coordinators must not directly construct `NSAlert`.

### Timer

Timer state continues to be deadline-authoritative.

Expected flow:

- user starts timer from status menu
- timer appears immediately
- remaining time refreshes
- pause/resume/cancel continue to work
- completion is persisted exactly once
- if system notification delivery is unavailable, completion is surfaced through the in-process fallback while SchneeRunner is running
- if the app is not running, no fallback completion notification is promised

Timer completion must not depend on notification delivery success.

### Pomodoro

Pomodoro remains deadline-authoritative and restart-safe.

When system notifications are unavailable, current-phase completion is surfaced through the same in-process fallback delivery abstraction. Auto-start behavior remains domain-owned and unchanged.

### Reminder

Reminder persistence and recurrence remain unchanged.

When system notifications are available, the existing scheduled-notification path remains authoritative for background delivery.

When they are unavailable, add an in-process reminder scheduler that evaluates the next due reminder/snooze while the app is running. It must:

- avoid duplicate delivery for one occurrence
- survive ordinary UI refreshes
- recompute from persisted state on launch
- stop cleanly on application termination
- preserve one-shot, daily, weekday, and snooze semantics
- feed the existing reminder-fired character reaction when delivery occurs

The UI must make the limitation clear: unsigned/bare runtimes can deliver reminders only while SchneeRunner is running.

### Launch at Login

`SMAppService.mainApp` is meaningful only for an application bundle. In bare `swift run` runtime the menu entry must be disabled and display a localized unavailable reason rather than attempting registration.

Unsigned packaged `.app` behavior remains whatever macOS `SMAppService` permits; no signing dependency is introduced by this design.

### Bundled default character in development

The built-in four-frame character should be usable from both the packaged app and `swift run`.

Move the source-of-truth assets into SwiftPM resources for `SchneeRunnerApp` or otherwise expose a single resource resolver capable of locating:

- `Bundle.module` resources for SwiftPM development
- `Bundle.main` resources for packaged application execution

Release packaging may still copy/verify the exact frames, but there must not be two independent asset definitions.

The user-selected stored character continues to take precedence over the bundled fallback.

## Localization architecture

### Supported languages

Initial supported localizations:

- English (`en`)
- Japanese (`ja`)

Use macOS language selection. No custom preference is added in this change.

### Resource format

Use String Catalogs (`Localizable.xcstrings`) if the SwiftPM/AppKit packaging path supports them cleanly in CI; otherwise use localized `.strings` resources under `en.lproj` and `ja.lproj`. The implementation plan must choose one format and test packaged-resource presence.

All application-facing strings must flow through a small app-layer localization API rather than scattered direct literals.

### Localization boundaries

Localize:

- status menu titles
- Timer UI
- Pomodoro UI
- Reminder UI
- management window labels/actions
- Desktop Character menu
- Character State presentation names
- Character Pack builder/import/export UI
- Launch at Login UI
- error/warning/informational alerts
- productivity notification/fallback presentation text
- availability/disabled explanations

Do not localize persisted/protocol values:

- `CharacterState.rawValue`
- character-pack manifest keys/enum values
- productivity state JSON schema
- notification identifier prefixes
- distributed-notification payloads
- CLI command names
- file extensions

Core types should expose stable semantic values. Localized presentation belongs in `SchneeRunnerApp`.

### Example Japanese terminology

Use consistent terminology:

- Timers → タイマー
- New Timer → 新しいタイマー
- Manage Timers… → タイマーを管理…
- Pause → 一時停止
- Resume → 再開
- Cancel → キャンセル
- Pomodoro → ポモドーロ
- Focus → 集中
- Short Break → 短い休憩
- Long Break → 長い休憩
- Reminders → リマインダー
- Recent Characters → 最近使ったキャラクター
- Character State → キャラクター状態
- Automatic → 自動
- CPU Adaptive Speed → CPU連動速度
- Launch at Login → ログイン時に起動
- Show on Desktop → デスクトップに表示
- Quit SchneeRunner → SchneeRunnerを終了

The implementation should centralize terminology so the same concept is not translated differently between menus, dialogs, notifications, and management windows.

## Architecture changes

### 1. `RuntimeCapabilities`

Add an app-layer value describing runtime capabilities. Construction is centralized near application startup and injected into productivity, launch-at-login, startup-resource, and related controllers where needed.

Avoid global mutable runtime flags.

### 2. Productivity delivery abstraction

Separate productivity **state management** from **completion presentation**.

Introduce a presentation/delivery abstraction suitable for both:

- system notification-backed delivery
- in-process AppKit fallback delivery

Existing stable notification identifiers remain unchanged for the system backend.

### 3. Reminder in-process scheduler

Add a dedicated application-layer scheduler/coordinator for due reminders when system scheduling is unavailable. It should use existing persisted reminder models and recurrence calculation rather than duplicating schedule semantics.

### 4. Resource resolver

Add one resolver for the built-in character that understands both SwiftPM and application-bundle resources. Update `StartupCharacterLoader` to consume the resolved resource root/URLs rather than assuming `Bundle.main.resourceURL` is sufficient.

### 5. Localization facade

Add a small typed/structured localization facade for app presentation. Do not move localization concerns into `SchneeRunnerCore`.

## Error handling

- Notification delivery failure never rolls back Timer/Pomodoro/Reminder state.
- Fallback presentation failure is logged and does not terminate the app.
- Missing localization keys fall back to English/key behavior according to the selected resource system and are covered by localization-resource tests.
- Missing bundled default-character resources do not prevent launch; the status menu still appears and import features remain available.
- Unsupported Launch at Login runtime becomes an explicit disabled state, not an exception path.

## Testing strategy

### Unit tests

Add tests for:

- runtime capability derivation for bare executable and `.app` bundle
- system-notification vs fallback delivery selection
- fallback Timer completion delivery
- fallback Pomodoro phase completion delivery
- in-process Reminder due evaluation
- duplicate Reminder occurrence suppression
- Reminder snooze fallback delivery
- Launch at Login availability policy
- built-in character resolution in SwiftPM and packaged-resource layouts
- localization lookup for English and Japanese
- localized CharacterState presentation without changing raw values

### Integration/E2E tests

Add application-level tests for:

1. menu Timer start → persisted running state → time advance/reconcile → completion → fallback presentation
2. Pomodoro start → phase completion → fallback presentation/state transition
3. Reminder create → due occurrence → fallback delivery while app is alive
4. notification-unavailable runtime still starts all productivity controllers
5. Japanese locale produces Japanese menu/action strings
6. English locale remains the default/fallback

### Release verification

Keep existing packaged `.app` and mounted-DMG launch smoke tests.

Additionally verify:

- localization resources exist in the packaged app
- English and Japanese localization resources are structurally valid
- built-in character resources exist exactly once in the expected packaged destination
- unsigned release continues to opt out of unsafe system-notification startup behavior unless a later unsigned-safe implementation is proven

Release validation must not claim that unsigned/notarized distribution bypasses Gatekeeper.

## Migration and compatibility

No migration is required for existing productivity state or character library data.

The following remain stable:

- Application Support paths
- timer/pomodoro/reminder JSON schema
- notification identifier prefixes
- character-pack format
- CLI commands and local distributed-notification payloads

Existing English user data such as saved timer titles is user content and is not rewritten.

## Delivery sequence

Implementation should be split into reviewable slices, each independently tested:

1. runtime capabilities + resource resolver
2. Timer/Pomodoro fallback completion presentation
3. Reminder in-process fallback scheduler
4. Launch at Login capability handling
5. localization infrastructure + status/productivity UI
6. remaining UI localization sweep
7. E2E and release-contract hardening

Do not publish a new release until all slices have passed the repository's normal CI and packaged launch smoke tests.

## Acceptance criteria

The work is complete when:

- `swift run SchneeRunner` starts without notification-runtime crashes
- `swift run` can use Timer/Pomodoro/Reminder while the app is running, including visible fallback completion/due presentation
- unsigned packaged `.app` remains launch-safe
- Timer/Pomodoro/Reminder domain state does not depend on system-notification availability
- built-in default character is available in both development and packaged runtimes
- Launch at Login is explicitly disabled when unsupported
- English and Japanese UI are available via macOS language selection
- persisted/protocol values are unchanged
- core productivity flows have application-level regression tests
- packaged release verification checks localization and built-in resources
- no Developer ID signing or notarization is introduced
