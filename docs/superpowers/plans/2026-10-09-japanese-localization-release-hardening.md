# Japanese Localization and Release Resource Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add English/Japanese AppKit localization and make the unsigned release pipeline verify localized resources and the unified built-in character resources without changing persisted/protocol values.

**Architecture:** Keep localization entirely in `SchneeRunnerApp`, backed by SwiftPM resources under `en.lproj` and `ja.lproj`, with an injectable app-layer `AppLocalization` value and typed helpers for domain presentation such as CharacterState. Reuse the SwiftPM resource bundle established by the runtime-parity plan and extend release verification so packaged `.app`/DMG contents are validated for both localizations.

**Tech Stack:** Swift 6, Swift Package Manager resources, AppKit, Foundation localization APIs, XCTest, existing shell release scripts.

**Spec:** `docs/superpowers/specs/2026-10-09-runtime-parity-japanese-localization-design.md`

**Dependency:** Implement `docs/superpowers/plans/2026-10-09-runtime-parity-productivity-fallback.md` Task 1 first so `SchneeRunnerApp` has one SwiftPM-managed resource bundle.

## Global Constraints

- Initial supported languages are English (`en`) and Japanese (`ja`).
- macOS language selection controls presentation; do not add a custom in-app language preference in this change.
- Localization stays in `SchneeRunnerApp`; `SchneeRunnerCore` persisted/protocol values remain locale-independent.
- Do not change `CharacterState.rawValue`, character-pack manifest values, productivity JSON schema, notification identifier prefixes, CLI command names, distributed-notification payloads, or file extensions.
- Developer ID signing and Apple notarization remain out of scope.
- Existing English user-authored content such as timer titles must never be rewritten.

## Review Focus

- Missing Japanese key: app falls back predictably to English rather than displaying an empty string or crashing.
- Japanese system locale with user-authored English timer/reminder text: chrome/actions localize, user content remains unchanged.
- CharacterState presentation: UI shows Japanese names while raw values and Character Pack parsing remain unchanged.
- Format strings/plurals: dynamic timer durations and status text interpolate safely in both locales.
- Packaged unsigned app: both `.lproj` resources and built-in images are present in the SwiftPM resource bundle inside the final DMG.

---

### Task 1: Add Localization Resources and an Injectable App-layer Lookup Facade

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SchneeRunnerApp/Resources/en.lproj/Localizable.strings`
- Create: `Sources/SchneeRunnerApp/Resources/ja.lproj/Localizable.strings`
- Create: `Sources/SchneeRunnerApp/AppLocalization.swift`
- Create: `Tests/SchneeRunnerAppTests/AppLocalizationTests.swift`
- Modify: `Tests/SchneeRunnerAppTests/CharacterStateStatusFormatterTests.swift`

**Interfaces:**
- Consumes: the SwiftPM resource bundle established by the runtime-parity plan.
- Produces: `struct AppLocalization: Sendable` initialized with `bundle: Bundle = .module` and optional `localeIdentifier: String? = nil`.
- Produces: `func string(_ key: String, arguments: CVarArg...) -> String` and `func characterState(_ state: CharacterState) -> String`.
- Produces: `static let system = AppLocalization()` as the default controller dependency; tests inject `AppLocalization(localeIdentifier: "ja")` or `"en"` rather than mutating process-global language state.
- English resources are the canonical fallback for missing Japanese keys.

- [ ] **Step 1: Write failing locale-lookup tests**

Assert exact values for representative keys:
- `menu.timers`: `Timers` / `タイマー`;
- `timer.new`: `New Timer` / `新しいタイマー`;
- `action.pause`: `Pause` / `一時停止`;
- `pomodoro.focus`: `Focus` / `集中`;
- `reminder.root`: `Reminders` / `リマインダー`;
- `launchAtLogin.title`: `Launch at Login` / `ログイン時に起動`.

Also assert an intentionally missing Japanese key falls back to the English resource.

- [ ] **Step 2: Write a failing CharacterState presentation test**

Assert `.idle.rawValue == "idle"` remains unchanged while localized presentation yields `Idle` in English and `待機` in Japanese. Use that Japanese term consistently across all UI.

- [ ] **Step 3: Run tests and verify RED**

Run: `swift test --filter AppLocalizationTests`
Expected: FAIL because localization resources/facade do not exist.

- [ ] **Step 4: Enable localized SwiftPM resources and implement the facade**

Set `defaultLocalization: "en"` in `Package(...)`. Keep the existing `SchneeRunnerApp` processed resource directory from the runtime-parity plan. Implement locale-specific lookup by selecting the requested `.lproj` sub-bundle when a test locale is injected; production `.system` follows macOS bundle localization. If a Japanese key is missing, explicitly retry the English table before returning the key.

- [ ] **Step 5: Run focused tests**

Run: `swift test --filter AppLocalizationTests`
Run: `swift test --filter CharacterStateStatusFormatterTests`
Expected: PASS without changing Core raw values.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/SchneeRunnerApp/Resources Sources/SchneeRunnerApp/AppLocalization.swift Tests/SchneeRunnerAppTests/AppLocalizationTests.swift Tests/SchneeRunnerAppTests/CharacterStateStatusFormatterTests.swift
git commit -m "feat: add English and Japanese localization resources"
```

---

### Task 2: Localize Status Menu and Productivity UI

**Files:**
- Modify: `Sources/SchneeRunnerApp/StatusMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/TimerMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/TimerApplicationController.swift`
- Modify: `Sources/SchneeRunnerApp/PomodoroMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/PomodoroSettingsController.swift`
- Modify: `Sources/SchneeRunnerApp/ReminderMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/ReminderEditorController.swift`
- Modify: `Sources/SchneeRunnerApp/ProductivityManagementWindowController.swift`
- Modify: `Sources/SchneeRunnerApp/ProductivityNotificationScheduler.swift`
- Modify: `Sources/SchneeRunnerApp/AppKitProductivityFallbackPresenter.swift`
- Extend: `Sources/SchneeRunnerApp/Resources/en.lproj/Localizable.strings`
- Extend: `Sources/SchneeRunnerApp/Resources/ja.lproj/Localizable.strings`
- Test: `Tests/SchneeRunnerAppTests/StatusMenuControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/TimerMenuControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/PomodoroMenuControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/ReminderMenuControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/ReminderEditorControllerTests.swift`
- Test: `Tests/SchneeRunnerAppTests/ProductivityManagementWindowControllerTests.swift`
- Create: `Tests/SchneeRunnerAppTests/JapaneseProductivityPresentationTests.swift`

**Interfaces:**
- Consumes: `AppLocalization` from Task 1.
- Every modified UI controller receives `localization: AppLocalization = .system` in its initializer, preserving existing call sites while making locale deterministic in tests.
- All visible Timer/Pomodoro/Reminder/status-menu chrome uses localization keys; user-entered titles/bodies remain untouched.
- Notification and fallback text uses the same terminology keys as menus where concepts overlap.

- [ ] **Step 1: Add RED Japanese status/productivity tests**

Construct controllers with `AppLocalization(localeIdentifier: "ja")` and assert menu/action labels for Timer, Pomodoro, Reminder, notification-disabled status, productivity reactions, and management actions.

- [ ] **Step 2: Add RED dynamic-format tests**

Assert examples such as `5 min` / `5分`, paused timer status, Pomodoro phase completion text, and reminder fallback body formatting use localized chrome while preserving the user title verbatim.

- [ ] **Step 3: Run focused tests and verify RED**

Run: `swift test --filter JapaneseProductivityPresentationTests`
Expected: FAIL because controllers still contain hard-coded English strings.

- [ ] **Step 4: Inject localization and replace hard-coded application-facing strings**

Add `localization: AppLocalization = .system` to the modified controller/presenter initializers and thread the same value through nested controllers so one UI tree cannot mix locales. Do not localize log-only developer diagnostics unless they are also user-visible. Do not rewrite persisted historical/user titles.

- [ ] **Step 5: Localize system-notification and fallback presentation content**

Use the same injected localization value for `Timer finished`, Pomodoro phase completion, reminder default body, and the in-process fallback presenter.

- [ ] **Step 6: Run focused tests and full suite**

Run: `swift test --filter JapaneseProductivityPresentationTests`
Run: `swift test --filter StatusMenuControllerTests`
Run: `swift test --filter TimerMenuControllerTests`
Run: `swift test --filter PomodoroMenuControllerTests`
Run: `swift test --filter ReminderMenuControllerTests`
Expected: PASS.

Run: `swift test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/SchneeRunnerApp Tests/SchneeRunnerAppTests
git commit -m "feat: localize productivity and status menu UI"
```

---

### Task 3: Localize Character, Desktop, Import/Export, and Launch-at-Login UI

**Files:**
- Modify: `Sources/SchneeRunnerApp/AppDelegate.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterStateMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterStateStatusFormatter.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterImportPresenter.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterPackBuilderPresenter.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterPackBuilderSourcePicker.swift`
- Modify: `Sources/SchneeRunnerApp/CharacterPackClipRowView.swift`
- Modify: `Sources/SchneeRunnerApp/DesktopCharacterMenuController.swift`
- Modify: `Sources/SchneeRunnerApp/LaunchAtLoginMenuController.swift`
- Extend: both `Localizable.strings` files
- Test: existing CharacterState, DesktopCharacter, Character Pack presenter, StatusMenu, and LaunchAtLogin tests
- Create: `Tests/SchneeRunnerAppTests/JapaneseGeneralPresentationTests.swift`

**Interfaces:**
- Consumes: the same `AppLocalization` instance threaded from `AppDelegate` into the menu/presenter tree.
- Core `displayName` helpers may remain for non-UI compatibility, but AppKit presentation must not depend on their English output.

- [ ] **Step 1: Add RED general Japanese UI tests**

Cover:
- Recent Characters empty/unavailable states;
- import panel titles;
- Character State root + Automatic + each state;
- Desktop Character root/actions;
- Character Pack builder labels/warnings;
- Launch at Login normal/approval/unavailable states;
- Quit SchneeRunner.

- [ ] **Step 2: Verify Core protocol values remain unchanged**

Add assertions that CharacterState raw values and representative Character Pack manifest enum values are identical before/after localization.

- [ ] **Step 3: Run tests and verify RED**

Run: `swift test --filter JapaneseGeneralPresentationTests`
Expected: FAIL on hard-coded English labels.

- [ ] **Step 4: Replace remaining user-facing literals with localized lookup**

Add defaulted localization dependencies where needed and preserve filenames, pack names, imported asset names, schema values, key equivalents, identifiers, and diagnostic log strings unless directly displayed to the user.

- [ ] **Step 5: Run focused and full tests**

Run: `swift test --filter JapaneseGeneralPresentationTests`
Run: `swift test --filter CharacterState`
Run: `swift test --filter DesktopCharacter`
Expected: PASS.

Run: `swift test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SchneeRunnerApp/Resources Sources/SchneeRunnerApp Tests/SchneeRunnerAppTests
git commit -m "feat: localize remaining SchneeRunner UI"
```

---

### Task 4: Harden Release Verification for Localization and Shared Resources

**Files:**
- Modify: `scripts/ci/build-release-artifact.sh`
- Modify: `scripts/release/verify-release.sh`
- Modify: release contract tests under the repository's existing release-test suite
- Modify: `README.md`
- Modify: `.github/workflows/` only where needed to expose/test the existing resource verification; do not add signing/notarization steps

**Interfaces:**
- Consumes: the SwiftPM resource bundle from runtime-parity Task 1 and localization resources from this plan.
- Release verifier must assert the final packaged app/DMG includes exactly one usable app resource bundle containing the four built-in PNGs plus both `en.lproj/Localizable.strings` and `ja.lproj/Localizable.strings`.

- [ ] **Step 1: Write RED release-contract tests**

Require build/release scripts to:
- package the SwiftPM resource bundle;
- verify four readable walk-cycle PNGs;
- verify English and Japanese localization files exist and are non-empty;
- reject a fixture missing either locale;
- retain `SchneeRunnerSystemNotificationsEnabled=false` for the unsigned release;
- retain packaged app and mounted-DMG launch smoke tests.

- [ ] **Step 2: Run release-contract tests and verify RED**

Run the repository's existing release contract test command(s) that cover `build-release-artifact.sh` and `verify-release.sh`.
Expected: FAIL on missing localization-resource assertions.

- [ ] **Step 3: Implement resource checks without adding signing/notarization**

Do not duplicate the character PNGs outside the SwiftPM resource source-of-truth. Verification should inspect the packaged resource bundle actually used by the app.

- [ ] **Step 4: Update README runtime limitations and Japanese support**

Document:
- unsigned distribution remains subject to Gatekeeper warnings;
- system notifications may be unavailable in unsigned/bare runtime;
- Timer/Pomodoro/Reminder use in-process fallback while SchneeRunner is running;
- reminders cannot be promised while the app is not running without system notifications;
- English/Japanese follow macOS language selection;
- Developer ID signing/notarization are not part of the project plan.

- [ ] **Step 5: Run complete verification**

Run: `swift test`
Expected: PASS.

Run all repository quality/release-contract tests.
Expected: PASS.

Run packaged `.app` launch smoke and mounted-DMG launch smoke.
Expected: process survives the existing smoke interval and resources are present.

Inspect the final app resource bundle and confirm both localizations and four PNGs are present exactly once.

- [ ] **Step 6: Commit**

```bash
git add scripts .github README.md Tests Sources/SchneeRunnerApp/Resources Package.swift
git commit -m "test: verify localized unsigned release resources"
```
