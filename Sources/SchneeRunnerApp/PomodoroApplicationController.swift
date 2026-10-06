import Foundation
import SchneeRunnerCore

@MainActor
final class PomodoroApplicationController: NSObject {
    private let menuController: StatusMenuController
    private let stateStore: ProductivityStateStore
    private let notificationScheduler: ProductivityNotificationScheduler
    private let refreshInterval: TimeInterval
    private var coordinator: PomodoroCoordinator?
    private var refreshTimer: Timer?

    init(
        menuController: StatusMenuController,
        fileManager: FileManager = .default,
        refreshInterval: TimeInterval = 1
    ) {
        self.menuController = menuController
        self.refreshInterval = refreshInterval
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        stateStore = ProductivityStateStore(
            baseDirectory: applicationSupportDirectory,
            fileManager: fileManager
        )
        notificationScheduler = ProductivityNotificationScheduler()
        super.init()
        configureMenuCallbacks()
    }

    func start() {
        do {
            let coordinator = try PomodoroCoordinator(
                store: stateStore,
                notificationScheduler: notificationScheduler
            )
            configureCoordinatorCallbacks(coordinator)
            self.coordinator = coordinator
            menuController.setPomodoroSession(
                coordinator.session,
                now: Date()
            )
            reconcileOnLaunch(coordinator)
            startRefreshing()
        } catch {
            log("Pomodoro state load error", error: error)
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func configureMenuCallbacks() {
        menuController.onStartPomodoro = { [weak self] configuration in
            self?.startSession(configuration: configuration)
        }
        menuController.onPausePomodoro = { [weak self] in
            self?.pauseSession()
        }
        menuController.onResumePomodoro = { [weak self] in
            self?.resumeSession()
        }
        menuController.onStartPomodoroPhase = { [weak self] in
            self?.startCurrentPhase()
        }
        menuController.onStopPomodoro = { [weak self] in
            self?.stopSession()
        }
    }

    private func configureCoordinatorCallbacks(
        _ coordinator: PomodoroCoordinator
    ) {
        coordinator.onChange = { [weak self] session in
            self?.menuController.setPomodoroSession(
                session,
                now: Date()
            )
        }
        coordinator.onNotificationStatus = { status in
            if status == .disabled {
                NSLog("SchneeRunner Pomodoro notifications are disabled")
            }
        }
        coordinator.onNotificationError = { [weak self] error in
            self?.log("Pomodoro notification error", error: error)
        }
    }

    private func reconcileOnLaunch(
        _ coordinator: PomodoroCoordinator
    ) {
        Task { @MainActor [weak self, weak coordinator] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.reconcile(now: Date())
            } catch {
                log("Pomodoro recovery error", error: error)
            }
        }
    }

    private func startRefreshing() {
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

    @objc
    private func refreshTimerDidFire(_: Timer) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.refresh(now: Date())
            } catch {
                log("Pomodoro refresh error", error: error)
            }
        }
    }

    private func startSession(configuration: PomodoroConfiguration) {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                _ = try await coordinator.start(
                    configuration: configuration,
                    now: Date()
                )
            } catch {
                log("Pomodoro start error", error: error)
            }
        }
    }

    private func pauseSession() {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.pause(now: Date())
            } catch {
                log("Pomodoro pause error", error: error)
            }
        }
    }

    private func resumeSession() {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.resume(now: Date())
            } catch {
                log("Pomodoro resume error", error: error)
            }
        }
    }

    private func startCurrentPhase() {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.startCurrentPhase(now: Date())
            } catch {
                log("Pomodoro phase start error", error: error)
            }
        }
    }

    private func stopSession() {
        Task { @MainActor [weak self] in
            guard let self, let coordinator else {
                return
            }
            do {
                try await coordinator.stop()
            } catch {
                log("Pomodoro stop error", error: error)
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
