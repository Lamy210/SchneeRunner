# Unsigned Runtime Parity and Productivity Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `swift run SchneeRunner` and the unsigned packaged app useful for Timer, Pomodoro, Reminder, built-in character loading, and runtime capability-dependent features without Developer ID signing or notarization.

**Architecture:** Centralize runtime capability detection in `SchneeRunnerApp`, keep productivity domain state independent from delivery, and add an injectable AppKit fallback presentation path when system notifications are unavailable. Move the built-in character to SwiftPM-managed resources so development and packaged execution share one source of truth.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, Foundation, UserNotifications, ServiceManagement, XCTest, existing shell release scripts.

**Spec:** `docs/superpowers/specs/2026-10-09-runtime-parity-japanese-localization-design.md`

## Global Constraints

- macOS 14 or later.
- Developer ID signing and Apple notarization are explicitly out of scope.
- Public release remains unsigned and must not weaken or bypass Gatekeeper.
- Timer/Pomodoro/Reminder persisted JSON schema and Application Support paths must remain compatible.
- Character Pack schema, notification identifier prefixes, CLI commands, and distributed-notification payloads must not change.
- System notifications must remain guarded; do not flip `SchneeRunnerSystemNotificationsEnabled` to `true` in unsigned releases.
- No network dependency may be introduced.

## Review Focus

- Bare executable runtime with no bundle identifier: Timer/Pomodoro/Reminder domain state still works and fallback delivery is selected instead of crashing.
- Sleep/wake or delayed run loop: Reminder fallback catches occurrences after the prior evaluation boundary without delivering the same occurrence twice.
- Missing built-in resources: status menu and imports still launch; no startup crash.
- Fallback presentation failure or dismissal: persisted productivity state remains correct and the app keeps running.
- Unsupported Launch at Login runtime: menu item is disabled with an explicit unavailable state and never attempts `SMAppService.register()`.

---

## Completion Status

Implemented and verified in PR #147.

- [x] Task 1 — Centralize Runtime Capabilities and Unify Built-in Resources
- [x] Task 2 — Timer/Pomodoro In-process Fallback Completion
- [x] Task 3 — Reminder In-process Fallback Scheduler
- [x] Task 4 — Capability-aware Launch at Login
- [x] Task 5 — Unsigned-runtime application-level regression coverage

Final verification head before merge: `9779783d8f3650e96f7923fe1040bad90944b26a`.

Fresh required workflows on that head:

- Tests: success
- Swift Quality: success
- Release Isolation TDD: success
- Test Infrastructure: success
- Quality: success
- SchneeRunner CI: success

The follow-up localization/release-resource work is intentionally tracked in `docs/superpowers/plans/2026-10-09-japanese-localization-release-hardening.md` and remains a separate implementation slice.
