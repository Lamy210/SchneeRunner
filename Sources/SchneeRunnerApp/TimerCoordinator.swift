import Foundation
import SchneeRunnerCore

enum TimerCoordinatorError: Error, Equatable {
    case timerNotFound(UUID)
}

@MainActor
final class TimerCoordinator: NSObject {
    var onChange: (([ProductivityCountdownTimer]) -> Void)?
    var onNotificationStatus: ((ProductivityNotificationDeliveryStatus) -> Void)?
    var onNotificationError: ((Error) -> Void)?
    var onPersistenceError: ((Error) -> Void)?

    private(set) var snapshot: ProductivitySnapshot

    private let store: ProductivityStateStore
    private let notificationScheduler: any ProductivityNotificationScheduling
    private let refreshInterval: TimeInterval
    private var refreshTimer: Timer?

    var timers: [ProductivityCountdownTimer] {
        snapshot.timers
    }

    init(
        snapshot: ProductivitySnapshot,
        store: ProductivityStateStore,
        notificationScheduler: any ProductivityNotificationScheduling,
        refreshInterval: TimeInterval = 1
    ) {
        self.snapshot = snapshot
        self.store = store
        self.notificationScheduler = notificationScheduler
        self.refreshInterval = refreshInterval
        super.init()
    }

    convenience init(
        store: ProductivityStateStore,
        notificationScheduler: any ProductivityNotificationScheduling,
        refreshInterval: TimeInterval = 1
    ) throws {
        try self.init(
            snapshot: store.load(),
            store: store,
            notificationScheduler: notificationScheduler,
            refreshInterval: refreshInterval
        )
    }

    func start(
        title: String,
        duration: TimeInterval,
        now: Date
    ) async throws -> UUID {
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: title,
            duration: duration,
            startedAt: now
        )
        try persist(timers + [timer])
        publish()
        await schedule(timer, now: now)
        return timer.id
    }

    func pause(
        id: UUID,
        now: Date
    ) async throws {
        let timer = try timer(id: id)
        let paused = try timer.pausing(at: now)
        try persist(replacing: paused)
        publish()
        await notificationScheduler.cancelTimer(id: id)
    }

    func resume(
        id: UUID,
        now: Date
    ) async throws {
        let timer = try timer(id: id)
        let resumed = try timer.resuming(at: now)
        try persist(replacing: resumed)
        publish()
        await schedule(resumed, now: now)
    }

    func cancel(id: UUID) async throws {
        let timer = try timer(id: id)
        let cancelled = timer.cancelling()
        if cancelled != timer {
            try persist(replacing: cancelled)
            publish()
        }
        await notificationScheduler.cancelTimer(id: id)
    }

    func reconcile(now: Date) async throws {
        let reconciled = try await reconcileState(now: now)

        do {
            let status = try await notificationScheduler.reconcileTimers(
                reconciled.timers,
                now: now
            )
            onNotificationStatus?(status)
        } catch {
            onNotificationError?(error)
        }
    }

    func startRefreshing() {
        guard refreshTimer == nil else {
            return
        }

        refreshTimer = CommonRunLoopTimerScheduler.schedule(
            timeInterval: refreshInterval,
            target: self,
            selector: #selector(refreshTick(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc
    private func refreshTick(_: Timer) {
        publish()
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                _ = try await reconcileState(now: Date())
            } catch {
                onPersistenceError?(error)
            }
        }
    }

    @discardableResult
    private func reconcileState(
        now: Date
    ) async throws -> ProductivitySnapshot {
        let previous = snapshot
        let reconciled = previous.reconciling(at: now)

        if reconciled != previous {
            try store.save(reconciled)
            snapshot = reconciled
            publish()

            for id in newlyCompletedTimerIDs(
                before: previous,
                after: reconciled
            ) {
                await notificationScheduler.cancelTimer(id: id)
            }
        }

        return reconciled
    }

    private func timer(id: UUID) throws -> ProductivityCountdownTimer {
        guard let timer = timers.first(where: { $0.id == id }) else {
            throw TimerCoordinatorError.timerNotFound(id)
        }
        return timer
    }

    private func persist(
        replacing timer: ProductivityCountdownTimer
    ) throws {
        var updated = timers
        guard let index = updated.firstIndex(where: { $0.id == timer.id }) else {
            throw TimerCoordinatorError.timerNotFound(id)
        }
        updated[index] = timer
        try persist(updated)
    }

    private func persist(_ timers: [ProductivityCountdownTimer]) throws {
        let updated = ProductivitySnapshot(timers: timers)
        try store.save(updated)
        snapshot = updated
    }

    private func schedule(
        _ timer: ProductivityCountdownTimer,
        now: Date
    ) async {
        do {
            let status = try await notificationScheduler.scheduleTimer(
                timer,
                now: now
            )
            onNotificationStatus?(status)
        } catch {
            onNotificationError?(error)
        }
    }

    private func publish() {
        onChange?(timers)
    }

    private func newlyCompletedTimerIDs(
        before: ProductivitySnapshot,
        after: ProductivitySnapshot
    ) -> [UUID] {
        let previousByID = Dictionary(
            uniqueKeysWithValues: before.timers.map { ($0.id, $0) }
        )
        return after.timers.compactMap { timer in
            guard
                timer.state == .completed,
                previousByID[timer.id]?.state == .running
            else {
                return nil
            }
            return timer.id
        }
    }
}
