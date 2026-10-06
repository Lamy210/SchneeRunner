import AppKit
import Foundation
import SchneeRunnerCore

@MainActor
final class TimerApplicationController {
    private let menuController: StatusMenuController
    private let managementWindow: ProductivityManagementWindowController?
    private let stateStore: ProductivityStateStore
    private let historyStore: ProductivityHistoryStore
    private let notificationScheduler: ProductivityNotificationScheduler
    private var coordinator: TimerCoordinator?

    init(
        menuController: StatusMenuController,
        managementWindow: ProductivityManagementWindowController? = nil,
        fileManager: FileManager = .default
    ) {
        self.menuController = menuController
        self.managementWindow = managementWindow
        let applicationSupportDirectory = fileManager.urls(
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
        notificationScheduler = ProductivityNotificationScheduler()
        configureMenuCallbacks()
        configureManagementCallbacks()
    }

    func start() {
        do {
            let coordinator = try TimerCoordinator(
                store: stateStore,
                notificationScheduler: notificationScheduler,
                historyRecorder: historyStore
            )
            configureCoordinatorCallbacks(coordinator)
            self.coordinator = coordinator
            updateViews(timers: coordinator.timers, now: Date())
            coordinator.startRefreshing()
            reconcileOnLaunch(coordinator)
        } catch {
            log("timer state load error", error: error)
        }
    }

    func stop() {
        coordinator?.stopRefreshing()
    }

    private func configureMenuCallbacks() {
        menuController.onStartTimerPreset = { [weak self] duration in
            self?.startPresetTimer(duration: duration)
        }
        menuController.onStartCustomTimer = { [weak self] in
            self?.startCustomTimer()
        }
        menuController.onManageTimers = { [weak self] in
            self?.showManagementWindow()
        }
        menuController.onPauseTimer = { [weak self] id in
            self?.pauseTimer(id: id)
        }
        menuController.onResumeTimer = { [weak self] id in
            self?.resumeTimer(id: id)
        }
        menuController.onCancelTimer = { [weak self] id in
            self?.cancelTimer(id: id)
        }
    }

    private func configureManagementCallbacks() {
        managementWindow?.onPauseTimer = { [weak self] id in
            self?.pauseTimer(id: id)
        }
        managementWindow?.onResumeTimer = { [weak self] id in
            self?.resumeTimer(id: id)
        }
        managementWindow?.onCancelTimer = { [weak self] id in
            self?.cancelTimer(id: id)
        }
    }

    private func configureCoordinatorCallbacks(
        _ coordinator: TimerCoordinator
    ) {
        coordinator.onChange = { [weak self] timers in
            self?.updateViews(timers: timers, now: Date())
        }
        coordinator.onNotificationStatus = { status in
            if status == .disabled {
                NSLog("SchneeRunner timer notifications are disabled")
            }
        }
        coordinator.onNotificationError = { [weak self] error in
            self?.log("timer notification error", error: error)
        }
        coordinator.onPersistenceError = { [weak self] error in
            self?.log("timer persistence error", error: error)
        }
        coordinator.onHistoryError = { [weak self] error in
            self?.log("timer history error", error: error)
        }
    }

    private func reconcileOnLaunch(
        _ coordinator: TimerCoordinator
    ) {
        Task { @MainActor [weak self, weak coordinator] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.reconcile(now: Date())
            } catch {
                log("timer recovery error", error: error)
            }
        }
    }

    private func updateViews(
        timers: [ProductivityCountdownTimer],
        now: Date
    ) {
        menuController.setTimers(timers, now: now)
        managementWindow?.setTimers(timers)
    }

    private func showManagementWindow() {
        guard
            let coordinator,
            let managementWindow
        else {
            return
        }
        updateViews(timers: coordinator.timers, now: Date())
        managementWindow.setHistory(loadHistory())
        managementWindow.show()
    }

    private func loadHistory() -> ProductivityHistory {
        do {
            return try historyStore.load()
        } catch {
            log("productivity history load error", error: error)
            return ProductivityHistory()
        }
    }

    private func startPresetTimer(duration: TimeInterval) {
        let minutes = max(1, Int(duration / 60))
        startTimer(
            title: "\(minutes) min Timer",
            duration: duration
        )
    }

    private func startCustomTimer() {
        let alert = NSAlert()
        alert.messageText = "New Timer"
        alert.informativeText = "Enter a duration in minutes."
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let minutesField = NSTextField(string: "25")
        minutesField.placeholderString = "Minutes"
        minutesField.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = minutesField

        guard
            alert.runModal() == .alertFirstButtonReturn,
            let minutes = Double(minutesField.stringValue),
            minutes.isFinite,
            minutes > 0
        else {
            return
        }

        startTimer(
            title: "Timer",
            duration: minutes * 60
        )
    }

    private func startTimer(
        title: String,
        duration: TimeInterval
    ) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                _ = try await coordinator.start(
                    title: title,
                    duration: duration,
                    now: Date()
                )
            } catch {
                log("timer start error", error: error)
            }
        }
    }

    private func pauseTimer(id: UUID) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.pause(id: id, now: Date())
            } catch {
                log("timer pause error", error: error)
            }
        }
    }

    private func resumeTimer(id: UUID) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.resume(id: id, now: Date())
            } catch {
                log("timer resume error", error: error)
            }
        }
    }

    private func cancelTimer(id: UUID) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.cancel(id: id)
            } catch {
                log("timer cancel error", error: error)
            }
        }
    }

    private func log(
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
