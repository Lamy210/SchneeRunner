# Productivity Timers and Reminders Design

Date: 2026-10-07

## 1. Intent

Add a first-class productivity subsystem to SchneeRunner that combines countdown timers, Pomodoro sessions, recurring reminders, snooze, history, and optional character reactions without weakening the existing separation between deterministic Core behavior and AppKit/macOS integration.

The feature must remain local-first, require no network service, continue to work while the status menu is open, recover correctly after sleep or app restart, and deliver scheduled reminders through macOS even while SchneeRunner is not running.

## 2. Scope

### Countdown timers

- Multiple timers may run concurrently.
- Presets: 5, 10, 15, 25, 30, and 60 minutes.
- Arbitrary user-selected durations are supported.
- Lifecycle: running, paused, completed, cancelled.
- Pause stores remaining duration; resume creates a new deadline.
- Completion creates history and may emit a short character reaction.

### Pomodoro

- One Pomodoro session may be active at a time.
- Defaults: 25 minute focus, 5 minute short break, 15 minute long break, long break after 4 focus phases.
- All durations and long-break cadence are configurable.
- Phases: focus, short break, long break.
- Auto-start of the next phase is configurable and defaults to off.
- Phase completion is recorded in history.

### Reminders

- Multiple reminders may exist concurrently.
- One-shot reminders.
- Daily reminders.
- Weekday-selected reminders.
- Enable/disable, edit, delete.
- Snooze options: 5, 10, 15, 30, and 60 minutes.
- Local notifications must remain deliverable when SchneeRunner is not running.

### Character reactions

Reactions are enabled by default but globally user-toggleable.

Suggested mapping:

- Pomodoro focus: dash.
- Break: idle.
- Active countdown: walk.
- Final minute: sprint.
- Timer completion: short sprint reaction.
- Reminder firing: short idle or attention reaction using an available state.

The productivity subsystem emits one aggregated trigger rather than one trigger per timer or reminder.

## 3. Existing architectural constraints

SchneeRunnerCore owns deterministic reusable behavior and must not own AppKit state, application lifecycle, timers, notification-center APIs, or other macOS-only integration.

SchneeRunnerApp owns scheduling, AppKit UI, UserNotifications integration, and main-actor mutation.

Existing CommonRunLoopTimerScheduler remains the App-layer mechanism for in-process periodic UI refresh so countdown display updates continue while AppKit is in event-tracking mode.

Existing CharacterStateTriggerEngine priority semantics remain intact. Manual state continues to have the highest priority. Productivity reactions use event priority and are aggregated internally before being submitted to the trigger engine.

## 4. Chosen timing model

Use a deadline-authoritative model.

A running timer stores an absolute deadline. Remaining time is always derived from `deadline - now`; one-second in-process timers are display refresh mechanisms only and are never the source of truth.

This avoids tick drift and supports:

- menu tracking;
- sleep/wake;
- delayed execution;
- process restart;
- app termination while a timer or reminder is pending.

Paused timers store remaining duration and no active deadline. Resume computes a fresh deadline from the current clock.

Wall-clock reminders use calendar semantics. Countdown timers use their persisted deadlines. Reconciliation always re-evaluates against the current clock.

## 5. Core domain model

Introduce deterministic value types and policies in SchneeRunnerCore.

### CountdownTimer

Fields:

- id: UUID
- title: String
- originalDuration: TimeInterval
- startedAt: Date?
- deadline: Date?
- pausedRemaining: TimeInterval?
- state: running | paused | completed | cancelled
- completedAt: Date?

Invalid combinations are rejected. Examples: running without deadline, paused without pausedRemaining, or negative durations.

### PomodoroConfiguration

Fields:

- focusDuration
- shortBreakDuration
- longBreakDuration
- focusPhasesBeforeLongBreak
- autoStartNextPhase

Durations must be positive and bounded to sensible application limits.

### PomodoroSession

Fields:

- id
- configuration snapshot
- currentPhase
- completedFocusCount
- phaseStartedAt
- phaseDeadline
- pausedRemaining
- lifecycle state

The session owns deterministic phase progression, not timer execution.

### Reminder

Fields:

- id
- title
- optional body
- enabled
- schedule
- createdAt
- updatedAt

Schedule variants:

- once(Date)
- daily(hour, minute)
- weekdays(Set<Weekday>, hour, minute)

The schedule policy computes the next occurrence after a supplied Date and Calendar.

### Snooze

Snooze is modeled as a temporary one-shot occurrence associated with a reminder ID. It does not rewrite the reminder's recurrence rule.

### Productivity history

History entries record observable completed events only:

- countdown completed
- Pomodoro focus completed
- Pomodoro break completed
- reminder delivered/acknowledged when observable in-app

History is bounded to the newest 500 entries.

## 6. App-layer components

### TimerCoordinator

Responsibilities:

- create, pause, resume, cancel timers;
- reconcile overdue timers;
- schedule/cancel matching local notifications;
- publish timer state to menu/UI;
- request persistence after state transitions.

### PomodoroCoordinator

Responsibilities:

- start, pause, resume, stop the single active Pomodoro session;
- transition phases using Core policy;
- schedule phase-completion notifications;
- record completed phases;
- honor auto-start configuration.

### ReminderCoordinator

Responsibilities:

- CRUD reminders;
- compute next occurrences through Core policy;
- schedule/cancel local notifications;
- manage snooze occurrences;
- reconcile persisted reminders against pending system notifications.

### NotificationScheduler

Narrow wrapper around UserNotifications.

Responsibilities:

- authorization state;
- create/update pending notification requests;
- cancel SchneeRunner-owned requests only;
- list pending SchneeRunner requests for reconciliation;
- keep stable logical identifiers.

It must not contain timer/Pomodoro/reminder business rules.

### ProductivityCharacterStateCoordinator

Aggregates productivity state and submits at most one trigger to CharacterStateTriggerEngine.

Internal productivity precedence:

1. reminder fired
2. timer completed
3. final minute
4. Pomodoro focus
5. active countdown
6. break

The global user toggle suppresses this trigger entirely when disabled.

### UI controllers

Status menu remains compact.

Timer submenu:

- New Timer...
- currently active timers with remaining time
- pause/resume/cancel actions
- Manage Timers...

Pomodoro submenu:

- Start Focus
- current phase and remaining time
- pause/resume/stop
- Settings...

Reminders submenu:

- next reminder summary
- New Reminder...
- Manage Reminders...

A separate management window handles timer lists, history, reminder editing, and Pomodoro configuration so StatusMenuController does not become a service locator or oversized UI type.

## 7. Persistence

Small preferences remain in UserDefaults:

- character-reaction toggle;
- Pomodoro defaults;
- optional UI preferences.

Productivity state and history are stored under Application Support:

```text
SchneeRunner/Productivity/
  state.json
  history.json
```

Both formats are versioned.

Persistence requirements:

- staged write;
- flush/synchronize the staged file before replacement where supported;
- atomic replacement/rename into the final path;
- no partial visible state;
- explicit validation on load;
- malformed or unsupported files are not silently overwritten.

State and history writes are separate so a history write failure does not invalidate an already-completed timer transition.

## 8. Notification identity and synchronization

Use stable request identifiers:

- `schneerunner.timer.<uuid>`
- `schneerunner.pomodoro.<session-uuid>.<phase>`
- `schneerunner.reminder.<uuid>.<occurrence-key>`
- `schneerunner.snooze.<uuid>`

On startup:

1. load and validate persisted state;
2. reconcile timers/Pomodoro against now;
3. query pending SchneeRunner notifications;
4. compute desired pending notifications;
5. add missing requests;
6. replace stale requests by stable identifier;
7. remove obsolete requests owned by known SchneeRunner productivity prefixes;
8. rebuild UI and character reaction state.

Never cancel unrelated application notifications.

## 9. Notification behavior

Notification permission is optional for core functionality.

If permission is denied:

- timers, Pomodoro, and reminders remain editable and runnable;
- in-app completion behavior still occurs while the app is active;
- UI reports notifications as disabled;
- the app does not repeatedly nag for authorization.

Use system local notifications for scheduled completion/reminder delivery. No helper daemon or LaunchAgent is introduced in this version.

## 10. Recovery and failure behavior

### Sleep and delayed execution

Recompute remaining time from persisted deadline rather than elapsed tick count.

### App restart

Restore persisted state and reconcile immediately.

### Overdue timer on restart

Transition it to completed exactly once and record history exactly once. Reconciliation must be idempotent.

### Clock changes

Countdowns continue from their persisted absolute deadline. Calendar reminders are recomputed from recurrence rules using the current Calendar and current wall clock.

### Persistence failure

A transition requiring durable state is not reported as fully successful unless the durable state update succeeds. Surface an actionable App-layer error.

### History failure

Do not roll back a completed timer merely because history persistence failed. Surface the history failure separately.

### Notification scheduling failure

Keep the domain state and expose degraded notification status. Do not corrupt or delete valid productivity data.

## 11. Testing strategy

### SchneeRunnerCore tests

- Countdown construction and validation.
- Remaining-time calculation.
- Pause/resume deadline generation.
- Idempotent completion reconciliation.
- Pomodoro phase transitions.
- Long-break cadence.
- Auto-start policy state transitions.
- Reminder next occurrence for one-shot, daily, and weekday schedules.
- DST/calendar edge cases where Calendar behavior is relevant.
- Snooze semantics.
- Productivity character-state precedence.
- Persistence DTO validation/version rejection.
- History cap behavior.

### SchneeRunnerApp tests

- Countdown refresh continues in event-tracking run-loop mode.
- Notification request identifier stability.
- Notification reconciliation add/replace/remove behavior.
- Permission denied behavior.
- Persistence staging/atomic replacement failure paths.
- Status-menu callbacks.
- Startup restoration and overdue reconciliation.
- Character-reaction global toggle.

Behavior changes should be introduced TDD-first at the lowest useful layer.

## 12. Delivery plan

Implement as focused pull requests rather than one large PR:

1. Core countdown model and deadline policy.
2. Countdown persistence and runtime coordinator.
3. Countdown status-menu UI and notification integration.
4. Pomodoro Core model and coordinator.
5. Productivity history.
6. Reminder Core model and recurrence policy.
7. Reminder notification synchronization and snooze.
8. Reminder/Pomodoro management UI.
9. Productivity character reactions.
10. Architecture/docs cleanup and end-to-end regression coverage.

Each PR uses a short-lived `feat/*` branch, required tests, SwiftFormat, SwiftLint, repository CI, review resolution, and squash merge before the next dependent stage is based on main.

## 13. Non-goals for this release

- Cloud synchronization.
- Cross-device reminders.
- Calendar-service integration.
- A privileged helper or LaunchAgent.
- Network APIs.
- Arbitrary scripting at reminder fire time.
- Replacing macOS Notification Center.

## 14. Acceptance criteria

The feature is complete when:

- multiple countdown timers can run, pause, resume, cancel, survive restart, and complete without tick drift;
- one configurable Pomodoro session supports focus/break progression and restart recovery;
- one-shot, daily, and weekday reminders survive app termination and are delivered through macOS notifications when permission is granted;
- snooze works without mutating recurrence rules;
- pending notification reconciliation is idempotent and limited to SchneeRunner-owned identifiers;
- history is bounded and persists valid completed activity;
- productivity character reactions are deterministic and user-toggleable;
- opening the status menu does not pause countdown UI refresh or existing animation/system-monitor behavior;
- malformed persisted productivity data does not silently overwrite good state;
- all repository-required CI, SwiftFormat, SwiftLint, and applicable tests pass before each merge.
