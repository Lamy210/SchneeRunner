import Foundation
import SchneeRunnerCore

@MainActor
final class InProcessReminderScheduler: NSObject {
    var onReminderDelivered: (() -> Void)?
    var onError: ((Error) -> Void)?

    private let stateStore: ProductivityStateStore
    private let presenter: any ProductivityFallbackPresenting
    private let deliveryStore: ReminderFallbackDeliveryStore
    private let calendar: Calendar
    private let refreshInterval: TimeInterval
    private var refreshTimer: Timer?
    private var lastEvaluationDate: Date?

    init(
        stateStore: ProductivityStateStore,
        presenter: any ProductivityFallbackPresenting,
        deliveryStore: ReminderFallbackDeliveryStore,
        calendar: Calendar = .current,
        refreshInterval: TimeInterval = 1
    ) {
        self.stateStore = stateStore
        self.presenter = presenter
        self.deliveryStore = deliveryStore
        self.calendar = calendar
        self.refreshInterval = refreshInterval
        super.init()
    }

    func start(now: Date = Date()) {
        guard refreshTimer == nil else {
            return
        }
        lastEvaluationDate = now
        refreshTimer = CommonRunLoopTimerScheduler.schedule(
            timeInterval: refreshInterval,
            target: self,
            selector: #selector(refreshTimerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        lastEvaluationDate = nil
    }

    @discardableResult
    func evaluate(now: Date) throws -> Int {
        guard let previousEvaluation = lastEvaluationDate else {
            lastEvaluationDate = now
            return 0
        }
        guard now >= previousEvaluation else {
            lastEvaluationDate = now
            return 0
        }

        let snapshot = try stateStore.load()
        var deliveredCount = 0

        for reminder in snapshot.reminders where reminder.enabled {
            guard
                let fireDate = reminder.nextOccurrence(
                    after: previousEvaluation,
                    calendar: calendar
                ),
                fireDate <= now
            else {
                continue
            }
            let occurrenceID = Self.occurrenceID(
                kind: "reminder",
                id: reminder.id,
                fireDate: fireDate
            )
            if deliver(
                occurrenceID: occurrenceID,
                event: .reminderDue(
                    title: reminder.title,
                    body: reminder.body
                )
            ) {
                deliveredCount += 1
            }
        }

        for snooze in snapshot.snoozes {
            guard
                snooze.fireDate > previousEvaluation,
                snooze.fireDate <= now
            else {
                continue
            }
            let occurrenceID = Self.occurrenceID(
                kind: "snooze",
                id: snooze.id,
                fireDate: snooze.fireDate
            )
            if deliver(
                occurrenceID: occurrenceID,
                event: .reminderDue(
                    title: snooze.title,
                    body: snooze.body
                )
            ) {
                deliveredCount += 1
            }
        }

        lastEvaluationDate = now
        return deliveredCount
    }

    @objc
    private func refreshTimerDidFire(_: Timer) {
        do {
            try evaluate(now: Date())
        } catch {
            onError?(error)
        }
    }

    private func deliver(
        occurrenceID: String,
        event: ProductivityFallbackEvent
    ) -> Bool {
        guard !deliveryStore.contains(occurrenceID) else {
            return false
        }
        deliveryStore.record(occurrenceID)
        presenter.present(event)
        onReminderDelivered?()
        return true
    }

    private static func occurrenceID(
        kind: String,
        id: UUID,
        fireDate: Date
    ) -> String {
        let timestampBits = fireDate.timeIntervalSinceReferenceDate.bitPattern
        return "\(kind):\(id.uuidString.lowercased()):\(timestampBits)"
    }
}
