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
    var onHistoryError: ((Error) -> Void)?

    private(set) var snapshot: ProductivitySnapshot

    private let store: ProductivityStateStore
    private let notificationScheduler: any ProductivityNotificationScheduling
    private let historyRecorder: (any ProductivityHistoryRecording)?
    private let refreshInterval: TimeInterval
    private var refreshTimer: Timer?

    var timers: [ProductivityCountdownTimer] {
        snapshot.timers
    }

    init(
        snapshot: ProductivitySnapshot,
        store: ProductivityStateStore,
        notificationScheduler: any ProductivityNotificationScheduling,
        historyRecorder: (any ProductivityHistoryRecording)? = nil,
        refreshInterval: TimeInterval = 1
    ) {
        self.snapshot = snapshot
        self.store = store
        self.notificationScheduler = notificationScheduler
        self.historyRecorder = historyRecorder
        self.refreshInterval = refreshInterval
        super.init()
    }

    convenience init(
        store: ProductivityStateStore,
        notificationScheduler: any ProductivityNotificationScheduling,
        historyRecorder: (any ProductivityHistoryRecording)? = nil,
        refreshInterval: TimeInterval = 1
    ) throws {
        try self.init(
            snapshot: store.load(),
            store: store,
            notificationScheduler: notificationScheduler,
            historyRecorder: historyRecorder,
            refreshInterval: refreshInterval
        )
    }

    func start(
        title: String,
        duration: TimeInterval,
        now: Date
    ) async throws -> UUID {
        try synchronizeSnapshot()
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
        try synchronizeSnapshot()
        let timer = try timer(id: id)
        let paused = try timer.pausing(at: now)
        try persist(replacing: paused)
        publish()
        recordCompletionIfNeeded(before: timer, after: paused)
        await notificationScheduler.cancelTimer(id: id)
    }

    func resume(
        id: UUID,
        now: Date
    ) async throws {
        try synchronizeSnapshot()
        let timer = try timer(id: id)
        let resumed = try timer.resuming(at: now)
        try persist(replacing: resumed)
        publish()
        await schedule(resumed, now: now)
    }

    func cancel(id: UUID) async throws {
        try synchronizeSnapshot()
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
            selector: #selector(refreshTimerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @objc
    private func refreshTimerDidFire(_: Timer) {
        refreshTick()
    }

    @objc
    private func refreshTick() {
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
        try synchronizeSnapshot()
        let previous = snapshot
        let reconciled = previous.replacingTimers(
            previous.timers.map { $0.reconciling(at: now) }
        )

        if reconciled != previous {
            try store.save(reconciled)
            snapshot = reconciled
            publish()

            for timer in newlyCompletedTimers(
                before: previous,
                after: reconciled
            ) {
                recordCompletion(timer)
                await notificationScheduler.cancelTimer(id: timer.id)
            }
        }

        return reconciled
    }

    private func synchronizeSnapshot() throws {
        snapshot = try store.load()
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
            throw TimerCoordinatorError.timerNotFound(timer.id)
        }
        updated[index] = timer
        try persist(updated)
    }

    private func persist(_ timers: [ProductivityCountdownTimer]) throws {
        let updated = snapshot.replacingTimers(timers)
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

    private func recordCompletionIfNeeded(
        before: ProductivityCountdownTimer,
        after: ProductivityCountdownTimer
    ) {
        guard before.state != .completed, after.state == .completed else {
            return
        }
        recordCompletion(after)
    }

    private func recordCompletion(_ timer: ProductivityCountdownTimer) {
        guard let historyRecorder, let completedAt = timer.completedAt else {
            return
        }

        do {
            try historyRecorder.record(
                ProductivityHistoryEntry(
                    id: UUID(),
                    kind: .countdownCompleted,
                    sourceID: timer.id,
                    title: timer.title,
                    occurredAt: completedAt
                )
            )
        } catch {
            onHistoryError?(error)
        }
    }

    private func newlyCompletedTimers(
        before: ProductivitySnapshot,
        after: ProductivitySnapshot
    ) -> [ProductivityCountdownTimer] {
        let previousByID = Dictionary(
            uniqueKeysWithValues: before.timers.map { ($0.id, $0) }
        )
        return after.timers.filter { timer in
            guard timer.state == .completed else {
                return false
            }
            return previousByID[timer.id]?.state != .completed
        }
    }
}
