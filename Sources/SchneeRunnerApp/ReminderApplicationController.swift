import Foundation
import SchneeRunnerCore

enum ReminderApplicationControllerError: Error, Equatable {
    case notStarted
}

@MainActor
final class ReminderApplicationController {
    private let menuController: StatusMenuController
    private let stateStore: ProductivityStateStore
    private let historyStore: ProductivityHistoryStore
    private let notificationScheduler: any ReminderNotificationScheduling
    private let editor = ReminderEditorController()
    private let managementWindow = ProductivityManagementWindowController()
    private let calendar: Calendar

    private var coordinator: ReminderCoordinator?

    init(
        menuController: StatusMenuController,
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        notificationScheduler: any ReminderNotificationScheduling = ProductivityNotificationScheduler(),
        calendar: Calendar = .current
    ) {
        self.menuController = menuController
        self.notificationScheduler = notificationScheduler
        self.calendar = calendar

        let applicationSupportDirectory = baseDirectory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        stateStore = ProductivityStateStore(
            baseDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        historyStore = ProductivityHistoryStore(
            baseDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        configureMenuCallbacks()
        configureManagementCallbacks()
    }

    func start(now: Date = Date()) {
        do {
            let coordinator = try ReminderCoordinator(
                store: stateStore,
                notificationScheduler: notificationScheduler,
                historyRecorder: historyStore,
                calendar: calendar
            )
            configureCoordinatorCallbacks(coordinator)
            self.coordinator = coordinator
            updateViews(reminders: coordinator.reminders, now: now)
            reconcileOnLaunch(coordinator, now: now)
        } catch {
            log("reminder state load error", error: error)
        }
    }

    func stop() {}

    @discardableResult
    func createReminder(
        _ request: ReminderEditRequest,
        now: Date = Date()
    ) async throws -> UUID {
        guard let coordinator else {
            throw ReminderApplicationControllerError.notStarted
        }
        return try await coordinator.create(
            title: request.title,
            body: request.body,
            schedule: request.schedule,
            enabled: request.enabled,
            now: now
        )
    }
}

private extension ReminderApplicationController {
    func configureMenuCallbacks() {
        menuController.onNewReminder = { [weak self] in
            self?.presentNewReminder()
        }
        menuController.onManageReminders = { [weak self] in
            self?.showManagementWindow()
        }
    }

    func configureManagementCallbacks() {
        managementWindow.onNewReminder = { [weak self] in
            self?.presentNewReminder()
        }
        managementWindow.onEditReminder = { [weak self] id in
            self?.presentEditReminder(id: id)
        }
        managementWindow.onDeleteReminder = { [weak self] id in
            self?.deleteReminder(id: id)
        }
        managementWindow.onSetReminderEnabled = { [weak self] id, enabled in
            self?.setReminderEnabled(id: id, enabled: enabled)
        }
        managementWindow.onSnoozeReminder = { [weak self] id, duration in
            self?.snoozeReminder(id: id, duration: duration)
        }
    }

    func configureCoordinatorCallbacks(
        _ coordinator: ReminderCoordinator
    ) {
        coordinator.onChange = { [weak self] reminders, _ in
            self?.updateViews(reminders: reminders, now: Date())
        }
        coordinator.onNotificationStatus = { status in
            if status == .disabled {
                NSLog("SchneeRunner reminder notifications are disabled")
            }
        }
        coordinator.onNotificationError = { [weak self] error in
            self?.log("reminder notification error", error: error)
        }
        coordinator.onHistoryError = { [weak self] error in
            self?.log("reminder history error", error: error)
        }
    }

    func reconcileOnLaunch(
        _ coordinator: ReminderCoordinator,
        now: Date
    ) {
        Task { @MainActor [weak self, weak coordinator] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.reconcile(now: now)
            } catch {
                log("reminder recovery error", error: error)
            }
        }
    }

    func updateViews(
        reminders: [ProductivityReminder],
        now: Date
    ) {
        menuController.setReminders(
            reminders,
            now: now,
            calendar: calendar
        )
        managementWindow.setContent(
            reminders: reminders,
            history: loadHistory()
        )
    }

    func loadHistory() -> ProductivityHistory {
        do {
            return try historyStore.load()
        } catch {
            log("productivity history load error", error: error)
            return ProductivityHistory()
        }
    }

    func showManagementWindow() {
        guard let coordinator else {
            return
        }
        updateViews(reminders: coordinator.reminders, now: Date())
        managementWindow.show()
    }

    func presentNewReminder() {
        guard let request = editor.present(
            now: Date(),
            calendar: calendar
        ) else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                _ = try await createReminder(request)
            } catch {
                log("reminder creation error", error: error)
            }
        }
    }

    func presentEditReminder(id: UUID) {
        guard
            let coordinator,
            let reminder = coordinator.reminders.first(where: { $0.id == id }),
            let request = editor.present(
                existing: reminder,
                now: Date(),
                calendar: calendar
            )
        else {
            return
        }

        Task { @MainActor [weak self, weak coordinator] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.update(
                    id: id,
                    title: request.title,
                    body: request.body,
                    schedule: request.schedule,
                    enabled: request.enabled,
                    now: Date()
                )
            } catch {
                log("reminder edit error", error: error)
            }
        }
    }

    func deleteReminder(id: UUID) {
        performReminderOperation("reminder delete error") { coordinator in
            try await coordinator.delete(id: id, now: Date())
        }
    }

    func setReminderEnabled(
        id: UUID,
        enabled: Bool
    ) {
        performReminderOperation("reminder enable error") { coordinator in
            try await coordinator.setEnabled(
                id: id,
                enabled: enabled,
                now: Date()
            )
        }
    }

    func snoozeReminder(
        id: UUID,
        duration: ReminderSnoozeDuration
    ) {
        performReminderOperation("reminder snooze error") { coordinator in
            _ = try await coordinator.snooze(
                id: id,
                duration: duration,
                now: Date()
            )
        }
    }

    func performReminderOperation(
        _ errorMessage: String,
        operation: @escaping @MainActor (ReminderCoordinator) async throws -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await operation(coordinator)
            } catch {
                log(errorMessage, error: error)
            }
        }
    }

    func log(
        _ message: String,
        error: Error
    ) {
        NSLog(
            "SchneeRunner %@: %@",
            message,
            String(describing: error)
        )
    }
}
