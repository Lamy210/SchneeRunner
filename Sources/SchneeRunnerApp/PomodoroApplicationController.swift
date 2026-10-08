import Foundation
import SchneeRunnerCore

@MainActor
final class PomodoroApplicationController: NSObject {
    var onSessionChanged: ((PomodoroSession?, Date) -> Void)?

    private let menuController: StatusMenuController
    private let managementWindow: ProductivityManagementWindowController?
    private let stateStore: ProductivityStateStore
    private let historyStore: ProductivityHistoryStore
    private let configurationStore: PomodoroConfigurationStore
    private let settingsController = PomodoroSettingsController()
    private let notificationScheduler: ProductivityNotificationScheduler
    private let refreshInterval: TimeInterval
    private var coordinator: PomodoroCoordinator?
    private var launchReconciliationTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var configuration: PomodoroConfiguration?
    private var isReconcilingOnLaunch = false

    init(
        menuController: StatusMenuController,
        managementWindow: ProductivityManagementWindowController? = nil,
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard,
        refreshInterval: TimeInterval = 1,
        notificationScheduler: ProductivityNotificationScheduler = .init()
    ) {
        self.menuController = menuController
        self.managementWindow = managementWindow
        self.notificationScheduler = notificationScheduler
        self.refreshInterval = refreshInterval
        configurationStore = PomodoroConfigurationStore(defaults: defaults)
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
        super.init()
        configureMenuCallbacks()
        configureManagementCallbacks()
    }

    func start() {
        let configuration = loadConfiguration()
        setConfiguration(configuration)

        do {
            let coordinator = try PomodoroCoordinator(
                store: stateStore,
                notificationScheduler: notificationScheduler,
                historyRecorder: historyStore
            )
            configureCoordinatorCallbacks(coordinator)
            self.coordinator = coordinator
            isReconcilingOnLaunch = true
            menuController.setPomodoroSession(
                coordinator.session,
                now: Date()
            )
            reconcileOnLaunch(coordinator)
        } catch {
            log("Pomodoro state load error", error: error)
        }
    }

    func stop() {
        launchReconciliationTask?.cancel()
        launchReconciliationTask = nil
        isReconcilingOnLaunch = false
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
        menuController.onPomodoroSettings = { [weak self] in
            self?.presentSettings()
        }
    }

    private func configureManagementCallbacks() {
        managementWindow?.onEditPomodoroSettings = { [weak self] configuration in
            self?.presentSettings(configuration: configuration)
        }
    }

    private func configureCoordinatorCallbacks(
        _ coordinator: PomodoroCoordinator
    ) {
        coordinator.onChange = { [weak self] session in
            guard let self else {
                return
            }
            publishSession(
                session,
                now: Date(),
                notifyReaction: !isReconcilingOnLaunch
            )
        }
        coordinator.onNotificationStatus = { [weak self] status in
            self?.menuController.setProductivityNotificationStatus(status)
            if status == .disabled {
                NSLog("SchneeRunner Pomodoro notifications are disabled")
            }
        }
        coordinator.onNotificationError = { [weak self] error in
            guard !(error is CancellationError) else {
                return
            }
            self?.log("Pomodoro notification error", error: error)
        }
        coordinator.onHistoryError = { [weak self] error in
            self?.log("Pomodoro history error", error: error)
        }
    }

    private func reconcileOnLaunch(
        _ coordinator: PomodoroCoordinator
    ) {
        launchReconciliationTask?.cancel()
        launchReconciliationTask = Task { @MainActor [weak self, weak coordinator] in
            guard
                !Task.isCancelled,
                let self,
                let coordinator
            else {
                return
            }
            do {
                try await coordinator.reconcile(now: Date())
            } catch is CancellationError {
                return
            } catch {
                log("Pomodoro recovery error", error: error)
            }
            guard !Task.isCancelled else {
                return
            }
            isReconcilingOnLaunch = false
            publishSession(coordinator.session, now: Date())
            startRefreshing()
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

    private func publishSession(
        _ session: PomodoroSession?,
        now: Date,
        notifyReaction: Bool = true
    ) {
        menuController.setPomodoroSession(session, now: now)
        if notifyReaction {
            onSessionChanged?(session, now)
        }
    }

    private func loadConfiguration() -> PomodoroConfiguration {
        do {
            return try configurationStore.load()
        } catch {
            log("Pomodoro configuration load error", error: error)
            return approvedDefaults()
        }
    }

    private func approvedDefaults() -> PomodoroConfiguration {
        do {
            return try PomodoroConfiguration()
        } catch {
            preconditionFailure("Approved Pomodoro defaults must remain valid")
        }
    }

    private func setConfiguration(_ configuration: PomodoroConfiguration) {
        self.configuration = configuration
        menuController.setPomodoroConfiguration(configuration)
        managementWindow?.setPomodoroConfiguration(configuration)
    }

    private func presentSettings() {
        presentSettings(configuration: configuration ?? loadConfiguration())
    }

    private func presentSettings(configuration: PomodoroConfiguration) {
        guard let updated = settingsController.present(configuration: configuration) else {
            return
        }

        do {
            try configurationStore.save(updated)
            setConfiguration(updated)
        } catch {
            log("Pomodoro configuration save error", error: error)
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
