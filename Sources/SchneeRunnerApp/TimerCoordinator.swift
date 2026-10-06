import Foundation
import SchneeRunnerCore

@MainActor
enum TimerCoordinatorError: Error, Equatable {
    case timerNotFound(UUID)
}

@MainActor
final class TimerCoordinator: NSObject {
    var onChange: (([ProductivityCountdownTimer]) -> Void)?
    var onNotificationResult: ((ProductivityNotificationSchedulingResult) -> Void)?
    var onPersistenceError: ((Error) -> Void)?

    var timers: [ProductivityCountdownTimer] {
        snapshot.timers
    }

    private let store: ProductivityStateStore
    private let notificationScheduler: any ProductivityNotificationScheduling
    private let refreshInterval: TimeInterval

    private var snapshot: ProductivitySnapshot
    private var refreshTimer: Timer?

    init(
        store: ProductivityStateStore,
        notificationScheduler: any ProductivityNotificationScheduling,
        refreshInterval: TimeInterval = 1
    ) throws {
        self.store = store
        self.notificationScheduler = notificationScheduler
        self.refreshInterval = refreshInterval
        snapshot = try store.load()
        super.init()
    }

    @discardableResult
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
        let updatedSnapshot = ProductivitySnapshot(
            timers: snapshot.timers + [timer]
        )
        try persist(updatedSnapshot)
        publish()
        await scheduleNotification(for: timer, now: now)
        return timer.id
    }

    func pause(id: UUID, now: Date) throws {
        let timer = try timer(id: id)
        let paused = try timer.pausing(at: now)
        try persist(replacing: paused)
        notificationScheduler.cancelTimer(id: id)
        publish()
    }

    func resume(id: UUID, now: Date) async throws {
        let timer = try timer(id: id)
        let resumed = try timer.resuming(at: now)
        try persist(replacing: resumed)
        publish()
        await scheduleNotification(for: resumed, now: now)
    }

    func cancel(id: UUID) throws {
        let timer = try timer(id: id)
        let cancelled = timer.cancelling()
        guard cancelled != timer else {
            return
        }

        try persist(replacing: cancelled)
        notificationScheduler.cancelTimer(id: id)
        publish()
    }

    func reconcile(now: Date) throws {
        let reconciled = snapshot.reconciling(at: now)
        let completedIDs = newlyCompletedTimerIDs(
            before: snapshot,
            after: reconciled
        )

        if reconciled != snapshot {
            try persist(reconciled)
            for id in completedIDs {
                notificationScheduler.cancelTimer(id: id)
            }
        }

        publish()
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
        do {
            try reconcile(now: Date())
        } catch {
            onPersistenceError?(error)
            publish()
        }
    }

    private func timer(id: UUID) throws -> ProductivityCountdownTimer {
        guard let timer = snapshot.timers.first(where: { $0.id == id }) else {
            throw TimerCoordinatorError.timerNotFound(id)
        }
        return timer
    }

    private func persist(replacing timer: ProductivityCountdownTimer) throws {
        let timers = snapshot.timers.map { current in
            current.id == timer.id ? timer : current
        }
        try persist(ProductivitySnapshot(timers: timers))
    }

    private func persist(_ updatedSnapshot: ProductivitySnapshot) throws {
        try store.save(updatedSnapshot)
        snapshot = updatedSnapshot
    }

    private func publish() {
        onChange?(snapshot.timers)
    }

    private func scheduleNotification(
        for timer: ProductivityCountdownTimer,
        now: Date
    ) async {
        guard let deadline = timer.deadline else {
            return
        }

        let result = await notificationScheduler.scheduleTimer(
            id: timer.id,
            title: timer.title,
            deadline: deadline,
            now: now
        )
        onNotificationResult?(result)
    }

    private func newlyCompletedTimerIDs(
        before: ProductivitySnapshot,
        after: ProductivitySnapshot
    ) -> [UUID] {
        let previousStates = Dictionary(
            uniqueKeysWithValues: before.timers.map { ($0.id, $0.state) }
        )
        return after.timers.compactMap { timer in
            guard
                timer.state == .completed,
                previousStates[timer.id] != .completed
            else {
                return nil
            }
            return timer.id
        }
    }
}
