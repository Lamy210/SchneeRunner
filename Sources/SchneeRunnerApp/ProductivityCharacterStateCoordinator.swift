import Foundation
import SchneeRunnerCore

@MainActor
final class ProductivityCharacterStateCoordinator {
    private let characterStateCoordinator: CharacterStateCoordinator
    private let reactionStore: ProductivityCharacterReactionStore
    private let statePolicy = ProductivityCharacterStatePolicy()
    private let transientReactionDuration: TimeInterval

    private var timers: [ProductivityCountdownTimer] = []
    private var pomodoroSession: PomodoroSession?
    private var timerCompletionAt: Date?
    private var reminderFiredAt: Date?

    init(
        characterStateCoordinator: CharacterStateCoordinator,
        reactionStore: ProductivityCharacterReactionStore = .init(),
        transientReactionDuration: TimeInterval = 3
    ) {
        self.characterStateCoordinator = characterStateCoordinator
        self.reactionStore = reactionStore
        self.transientReactionDuration = max(0, transientReactionDuration)
    }

    var isEnabled: Bool {
        reactionStore.isEnabled
    }

    func updateTimers(
        _ timers: [ProductivityCountdownTimer],
        now: Date = Date()
    ) {
        if hasNewCompletion(in: timers), reactionStore.isEnabled {
            timerCompletionAt = now
        }
        self.timers = timers
        publishState(at: now)
    }

    func updatePomodoro(
        _ session: PomodoroSession?,
        now: Date = Date()
    ) {
        pomodoroSession = session
        publishState(at: now)
    }

    func recordTimerCompletion(at now: Date = Date()) {
        guard reactionStore.isEnabled else {
            return
        }
        timerCompletionAt = now
        publishState(at: now)
    }

    func recordReminderFired(at now: Date = Date()) {
        guard reactionStore.isEnabled else {
            return
        }
        reminderFiredAt = now
        publishState(at: now)
    }

    func setReactionsEnabled(
        _ isEnabled: Bool,
        now: Date = Date()
    ) {
        reactionStore.isEnabled = isEnabled
        if !isEnabled {
            timerCompletionAt = nil
            reminderFiredAt = nil
        }
        publishState(at: now)
    }

    func refresh(now: Date = Date()) {
        discardExpiredTransientSignals(at: now)
        publishState(at: now)
    }
}

private extension ProductivityCharacterStateCoordinator {
    func hasNewCompletion(
        in updatedTimers: [ProductivityCountdownTimer]
    ) -> Bool {
        let previousByID = Dictionary(
            uniqueKeysWithValues: timers.map { ($0.id, $0.state) }
        )
        return updatedTimers.contains { timer in
            guard timer.state == .completed else {
                return false
            }
            guard let previousState = previousByID[timer.id] else {
                return false
            }
            return previousState != .completed
        }
    }

    func publishState(at now: Date) {
        guard reactionStore.isEnabled else {
            characterStateCoordinator.setProductivityState(nil)
            return
        }

        characterStateCoordinator.setProductivityState(
            statePolicy.state(for: signals(at: now))
        )
    }

    func signals(at now: Date) -> [ProductivityCharacterStateSignal] {
        var signals: [ProductivityCharacterStateSignal] = []

        appendTimerSignals(to: &signals, now: now)
        appendPomodoroSignals(to: &signals)

        if isTransientActive(timerCompletionAt, at: now) {
            signals.append(.timerCompleted)
        }
        if isTransientActive(reminderFiredAt, at: now) {
            signals.append(.reminderFired)
        }

        return signals
    }

    func appendTimerSignals(
        to signals: inout [ProductivityCharacterStateSignal],
        now: Date
    ) {
        var hasActiveCountdown = false
        var hasFinalMinute = false

        for timer in timers where timer.state == .running || timer.state == .paused {
            let remaining = timer.remaining(at: now)
            guard remaining > 0 else {
                continue
            }
            hasActiveCountdown = true
            if remaining <= 60 {
                hasFinalMinute = true
            }
        }

        if hasActiveCountdown {
            signals.append(.activeCountdown)
        }
        if hasFinalMinute {
            signals.append(.finalMinute)
        }
    }

    func appendPomodoroSignals(
        to signals: inout [ProductivityCharacterStateSignal]
    ) {
        guard let pomodoroSession else {
            return
        }

        switch pomodoroSession.currentPhase {
        case .focus:
            if pomodoroSession.state != .waiting {
                signals.append(.pomodoroFocus)
            }
        case .shortBreak, .longBreak:
            signals.append(.breakPhase)
        }
    }

    func isTransientActive(
        _ occurredAt: Date?,
        at now: Date
    ) -> Bool {
        guard let occurredAt else {
            return false
        }
        let elapsed = now.timeIntervalSince(occurredAt)
        return elapsed >= 0 && elapsed < transientReactionDuration
    }

    func discardExpiredTransientSignals(at now: Date) {
        if !isTransientActive(timerCompletionAt, at: now) {
            timerCompletionAt = nil
        }
        if !isTransientActive(reminderFiredAt, at: now) {
            reminderFiredAt = nil
        }
    }
}
