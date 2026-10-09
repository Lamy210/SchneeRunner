import Foundation
import SchneeRunnerCore

enum PomodoroCoordinatorError: Error, Equatable {
    case noActiveSession
    case sessionAlreadyActive(UUID)
}

@MainActor
protocol PomodoroNotificationScheduling: AnyObject {
    func schedulePomodoro(
        _ session: PomodoroSession,
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus

    func cancelPomodoro(id: UUID) async

    func reconcilePomodoro(
        _ session: PomodoroSession?,
        now: Date
    ) async throws -> ProductivityNotificationDeliveryStatus
}

@MainActor
final class PomodoroCoordinator {
    var onChange: ((PomodoroSession?) -> Void)?
    var onNotificationStatus: ((ProductivityNotificationDeliveryStatus) -> Void)?
    var onNotificationError: ((Error) -> Void)?
    var onHistoryError: ((Error) -> Void)?
    var onPhaseCompleted: ((PomodoroSession, Date) -> Void)?

    private(set) var snapshot: ProductivitySnapshot

    private let store: ProductivityStateStore
    private let notificationScheduler: any PomodoroNotificationScheduling
    private let historyRecorder: (any ProductivityHistoryRecording)?

    var session: PomodoroSession? {
        snapshot.pomodoro
    }

    init(
        snapshot: ProductivitySnapshot,
        store: ProductivityStateStore,
        notificationScheduler: any PomodoroNotificationScheduling,
        historyRecorder: (any ProductivityHistoryRecording)? = nil
    ) {
        self.snapshot = snapshot
        self.store = store
        self.notificationScheduler = notificationScheduler
        self.historyRecorder = historyRecorder
    }

    convenience init(
        store: ProductivityStateStore,
        notificationScheduler: any PomodoroNotificationScheduling,
        historyRecorder: (any ProductivityHistoryRecording)? = nil
    ) throws {
        try self.init(
            snapshot: store.load(),
            store: store,
            notificationScheduler: notificationScheduler,
            historyRecorder: historyRecorder
        )
    }

    func start(
        configuration: PomodoroConfiguration,
        now: Date
    ) async throws -> UUID {
        try synchronizeSnapshot()
        if let session {
            throw PomodoroCoordinatorError.sessionAlreadyActive(session.id)
        }

        let session = try PomodoroSession(
            id: UUID(),
            configuration: configuration,
            startedAt: now
        )
        try persist(session)
        publish()
        await schedule(session, now: now)
        return session.id
    }

    func pause(now: Date) async throws {
        try synchronizeSnapshot()
        let session = try activeSession()
        let paused = try session.pausing(at: now)
        try persist(paused)
        publish()
        recordCompletedPhaseIfNeeded(before: session, after: paused)

        if paused.state == .running {
            await schedule(paused, now: now)
        } else {
            await notificationScheduler.cancelPomodoro(id: session.id)
        }
    }

    func resume(now: Date) async throws {
        try synchronizeSnapshot()
        let resumed = try activeSession().resuming(at: now)
        try persist(resumed)
        publish()
        await schedule(resumed, now: now)
    }

    func startCurrentPhase(now: Date) async throws {
        try synchronizeSnapshot()
        let started = try activeSession().startingCurrentPhase(at: now)
        try persist(started)
        publish()
        await schedule(started, now: now)
    }

    func stop() async throws {
        try synchronizeSnapshot()
        let session = try activeSession()
        try persist(nil)
        publish()
        await notificationScheduler.cancelPomodoro(id: session.id)
    }

    func refresh(now: Date) async throws {
        try synchronizeSnapshot()
        let previous = session
        let reconciled = previous?.advancing(at: now)

        if reconciled != previous {
            try persist(reconciled)
            publish()
            recordCompletedPhaseIfNeeded(before: previous, after: reconciled)
            await reconcileNotifications(reconciled, now: now)
        } else {
            publish()
        }
    }

    func reconcile(now: Date) async throws {
        try synchronizeSnapshot()
        let previous = session
        let reconciled = previous?.advancing(at: now)

        if reconciled != previous {
            try persist(reconciled)
            publish()
            recordCompletedPhaseIfNeeded(before: previous, after: reconciled)
        }

        await reconcileNotifications(reconciled, now: now)
    }
}

private extension PomodoroCoordinator {
    func synchronizeSnapshot() throws {
        snapshot = try store.load()
    }

    func activeSession() throws -> PomodoroSession {
        guard let session else {
            throw PomodoroCoordinatorError.noActiveSession
        }
        return session
    }

    func persist(_ session: PomodoroSession?) throws {
        let updated = snapshot.replacingPomodoro(session)
        try store.save(updated)
        snapshot = updated
    }

    func schedule(
        _ session: PomodoroSession,
        now: Date
    ) async {
        do {
            let status = try await notificationScheduler.schedulePomodoro(
                session,
                now: now
            )
            onNotificationStatus?(status)
        } catch {
            onNotificationError?(error)
        }
    }

    func reconcileNotifications(
        _ session: PomodoroSession?,
        now: Date
    ) async {
        do {
            let status = try await notificationScheduler.reconcilePomodoro(
                session,
                now: now
            )
            onNotificationStatus?(status)
        } catch {
            onNotificationError?(error)
        }
    }

    func publish() {
        onChange?(session)
    }

    func recordCompletedPhaseIfNeeded(
        before: PomodoroSession?,
        after: PomodoroSession?
    ) {
        guard
            let before,
            let after,
            before.currentPhase != after.currentPhase,
            let occurredAt = before.phaseDeadline
        else {
            return
        }
        recordCompletedPhase(before, occurredAt: occurredAt)
        onPhaseCompleted?(before, occurredAt)
    }

    func recordCompletedPhase(
        _ session: PomodoroSession,
        occurredAt: Date
    ) {
        guard let historyRecorder else {
            return
        }

        let kind: ProductivityHistoryKind
        let title: String
        switch session.currentPhase {
        case .focus:
            kind = .pomodoroFocusCompleted
            title = "Pomodoro Focus"
        case .shortBreak:
            kind = .pomodoroBreakCompleted
            title = "Pomodoro Short Break"
        case .longBreak:
            kind = .pomodoroBreakCompleted
            title = "Pomodoro Long Break"
        }

        do {
            try historyRecorder.record(
                ProductivityHistoryEntry(
                    id: UUID(),
                    kind: kind,
                    sourceID: session.id,
                    title: title,
                    occurredAt: occurredAt
                )
            )
        } catch {
            onHistoryError?(error)
        }
    }
}
