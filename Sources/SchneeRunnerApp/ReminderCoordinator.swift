import Foundation
import SchneeRunnerCore

enum ReminderCoordinatorError: Error, Equatable {
    case reminderNotFound(UUID)
}

@MainActor
final class ReminderCoordinator {
    var onChange: (([ProductivityReminder], [ReminderSnooze]) -> Void)?
    var onNotificationStatus: ((ProductivityNotificationDeliveryStatus) -> Void)?
    var onNotificationError: ((Error) -> Void)?
    var onHistoryError: ((Error) -> Void)?

    private(set) var snapshot: ProductivitySnapshot

    private let store: ProductivityStateStore
    private let notificationScheduler: any ReminderNotificationScheduling
    private let historyRecorder: (any ProductivityHistoryRecording)?
    private let calendar: Calendar

    var reminders: [ProductivityReminder] {
        snapshot.reminders
    }

    var snoozes: [ReminderSnooze] {
        snapshot.snoozes
    }

    init(
        snapshot: ProductivitySnapshot,
        store: ProductivityStateStore,
        notificationScheduler: any ReminderNotificationScheduling,
        historyRecorder: (any ProductivityHistoryRecording)? = nil,
        calendar: Calendar = .current
    ) {
        self.snapshot = snapshot
        self.store = store
        self.notificationScheduler = notificationScheduler
        self.historyRecorder = historyRecorder
        self.calendar = calendar
    }

    convenience init(
        store: ProductivityStateStore,
        notificationScheduler: any ReminderNotificationScheduling,
        historyRecorder: (any ProductivityHistoryRecording)? = nil,
        calendar: Calendar = .current
    ) throws {
        try self.init(
            snapshot: store.load(),
            store: store,
            notificationScheduler: notificationScheduler,
            historyRecorder: historyRecorder,
            calendar: calendar
        )
    }

    func create(
        title: String,
        body: String?,
        schedule: ReminderSchedule,
        enabled: Bool,
        now: Date
    ) async throws -> UUID {
        try synchronizeSnapshot()
        let reminder = try ProductivityReminder(
            id: UUID(),
            title: title,
            body: body,
            enabled: enabled,
            schedule: schedule,
            createdAt: now,
            updatedAt: now
        )
        try persist(
            reminders: reminders + [reminder],
            snoozes: snoozes
        )
        publish()
        await reconcileNotifications(now: now)
        return reminder.id
    }

    func update(
        id: UUID,
        title: String,
        body: String?,
        schedule: ReminderSchedule,
        enabled: Bool,
        now: Date
    ) async throws {
        try synchronizeSnapshot()
        let existing = try reminder(id: id)
        let updated = try ProductivityReminder(
            id: existing.id,
            title: title,
            body: body,
            enabled: enabled,
            schedule: schedule,
            createdAt: existing.createdAt,
            updatedAt: now
        )
        try persist(replacing: updated)
        publish()
        await reconcileNotifications(now: now)
    }

    func setEnabled(
        id: UUID,
        enabled: Bool,
        now: Date
    ) async throws {
        try synchronizeSnapshot()
        let existing = try reminder(id: id)
        let updated = try ProductivityReminder(
            id: existing.id,
            title: existing.title,
            body: existing.body,
            enabled: enabled,
            schedule: existing.schedule,
            createdAt: existing.createdAt,
            updatedAt: now
        )
        try persist(replacing: updated)
        publish()
        await reconcileNotifications(now: now)
    }

    func delete(
        id: UUID,
        now: Date
    ) async throws {
        try synchronizeSnapshot()
        _ = try reminder(id: id)
        try persist(
            reminders: reminders.filter { $0.id != id },
            snoozes: snoozes.filter { $0.reminderID != id }
        )
        publish()
        await reconcileNotifications(now: now)
    }

    func snooze(
        id: UUID,
        duration: ReminderSnoozeDuration,
        now: Date
    ) async throws -> UUID {
        try synchronizeSnapshot()
        let reminder = try reminder(id: id)
        let snooze = ReminderSnooze(
            id: UUID(),
            reminder: reminder,
            duration: duration,
            now: now
        )
        try persist(
            reminders: reminders,
            snoozes: snoozes.filter { $0.reminderID != id } + [snooze]
        )
        publish()
        recordAcknowledgement(reminder, at: now)
        await reconcileNotifications(now: now)
        return snooze.id
    }

    func reconcile(now: Date) async throws {
        try synchronizeSnapshot()
        let activeSnoozes = snoozes.filter { $0.fireDate > now }
        if activeSnoozes != snoozes {
            try persist(
                reminders: reminders,
                snoozes: activeSnoozes
            )
            publish()
        }
        await reconcileNotifications(now: now)
    }

    private func synchronizeSnapshot() throws {
        snapshot = try store.load()
    }

    private func reminder(id: UUID) throws -> ProductivityReminder {
        guard let reminder = reminders.first(where: { $0.id == id }) else {
            throw ReminderCoordinatorError.reminderNotFound(id)
        }
        return reminder
    }

    private func persist(replacing reminder: ProductivityReminder) throws {
        var updated = reminders
        guard let index = updated.firstIndex(where: { $0.id == reminder.id }) else {
            throw ReminderCoordinatorError.reminderNotFound(reminder.id)
        }
        updated[index] = reminder
        try persist(
            reminders: updated,
            snoozes: snoozes
        )
    }

    private func persist(
        reminders: [ProductivityReminder],
        snoozes: [ReminderSnooze]
    ) throws {
        let updated = ProductivitySnapshot(
            timers: snapshot.timers,
            reminders: reminders,
            pomodoro: snapshot.pomodoro,
            snoozes: snoozes
        )
        try store.save(updated)
        snapshot = updated
    }

    private func reconcileNotifications(now: Date) async {
        do {
            let status = try await notificationScheduler.reconcileReminders(
                reminders,
                snoozes: snoozes,
                now: now,
                calendar: calendar
            )
            onNotificationStatus?(status)
        } catch {
            onNotificationError?(error)
        }
    }

    private func recordAcknowledgement(
        _ reminder: ProductivityReminder,
        at date: Date
    ) {
        guard let historyRecorder else {
            return
        }

        do {
            try historyRecorder.record(
                ProductivityHistoryEntry(
                    id: UUID(),
                    kind: .reminderAcknowledged,
                    sourceID: reminder.id,
                    title: reminder.title,
                    occurredAt: date
                )
            )
        } catch {
            onHistoryError?(error)
        }
    }

    private func publish() {
        onChange?(reminders, snoozes)
    }
}
