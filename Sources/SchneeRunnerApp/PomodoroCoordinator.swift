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

    private(set) var snapshot: ProductivitySnapshot

    private let store: ProductivityStateStore
    private let notificationScheduler: any PomodoroNotificationScheduling

    var session: PomodoroSession? {
        snapshot.pomodoro
    }

    init(
        snapshot: ProductivitySnapshot,
        store: ProductivityStateStore,
        notificationScheduler: any PomodoroNotificationScheduling
    ) {
        self.snapshot = snapshot
        self.store = store
        self.notificationScheduler = notificationScheduler
    }

    convenience init(
        store: ProductivityStateStore,
        notificationScheduler: any PomodoroNotificationScheduling
    ) throws {
        try self.init(
            snapshot: store.load(),
            store: store,
            notificationScheduler: notificationScheduler
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
}
