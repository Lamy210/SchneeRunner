import SchneeRunnerCore

@MainActor
final class ProductivityApplicationController {
    private let menuController: StatusMenuController
    private let managementWindow: ProductivityManagementWindowController
    private let timerController: TimerApplicationController
    private let pomodoroController: PomodoroApplicationController
    private let reminderController: ReminderApplicationController
    private let reactionCoordinator: ProductivityCharacterStateCoordinator
    private let notificationDeliveryMonitor: ProductivityNotificationDeliveryMonitor

    init(
        menuController: StatusMenuController,
        characterStateCoordinator: CharacterStateCoordinator,
        reactionStore: ProductivityCharacterReactionStore = .init(),
        notificationDeliveryMonitor: ProductivityNotificationDeliveryMonitor = .init(),
        notificationScheduler: ProductivityNotificationScheduler? = nil,
        fallbackPresenter: (any ProductivityFallbackPresenting)? = nil,
        localization: AppLocalization = .current
    ) {
        LaunchTrace.emit("ProductivityApplicationController init begin")
        self.menuController = menuController
        self.notificationDeliveryMonitor = notificationDeliveryMonitor
        let managementWindow = ProductivityManagementWindowController(
            localization: localization
        )
        self.managementWindow = managementWindow
        let reactionCoordinator = ProductivityCharacterStateCoordinator(
            characterStateCoordinator: characterStateCoordinator,
            reactionStore: reactionStore
        )
        self.reactionCoordinator = reactionCoordinator
        LaunchTrace.emit("ProductivityApplicationController before notification scheduler")
        let notificationScheduler = notificationScheduler
            ?? ProductivityNotificationScheduler(localization: localization)
        let fallbackPresenter = fallbackPresenter
            ?? AppKitProductivityFallbackPresenter(localization: localization)
        LaunchTrace.emit("ProductivityApplicationController after notification scheduler")

        timerController = TimerApplicationController(
            menuController: menuController,
            managementWindow: managementWindow,
            notificationScheduler: notificationScheduler,
            fallbackPresenter: fallbackPresenter,
            localization: localization
        )
        pomodoroController = PomodoroApplicationController(
            menuController: menuController,
            managementWindow: managementWindow,
            notificationScheduler: notificationScheduler,
            fallbackPresenter: fallbackPresenter,
            localization: localization
        )
        reminderController = ReminderApplicationController(
            menuController: menuController,
            notificationScheduler: notificationScheduler,
            managementWindow: managementWindow,
            fallbackPresenter: fallbackPresenter,
            localization: localization
        )

        timerController.onTimersChanged = { [weak reactionCoordinator] timers, now in
            reactionCoordinator?.updateTimers(timers, now: now)
        }
        pomodoroController.onSessionChanged = { [weak reactionCoordinator] session, now in
            reactionCoordinator?.updatePomodoro(session, now: now)
        }
        notificationDeliveryMonitor.onReminderFired = { [weak reactionCoordinator] in
            reactionCoordinator?.recordReminderFired()
        }
        reminderController.onReminderFired = { [weak reactionCoordinator] in
            reactionCoordinator?.recordReminderFired()
        }
        menuController.onToggleProductivityCharacterReactions = { [weak self] in
            self?.toggleCharacterReactions()
        }
        menuController.setProductivityCharacterReactionsEnabled(
            reactionCoordinator.isEnabled
        )
        LaunchTrace.emit("ProductivityApplicationController init end")
    }

    func start() {
        LaunchTrace.emit("ProductivityApplicationController.start begin")
        LaunchTrace.emit("before notificationDeliveryMonitor.start")
        notificationDeliveryMonitor.start()
        LaunchTrace.emit("after notificationDeliveryMonitor.start")
        LaunchTrace.emit("before timerController.start")
        timerController.start()
        LaunchTrace.emit("after timerController.start")
        LaunchTrace.emit("before pomodoroController.start")
        pomodoroController.start()
        LaunchTrace.emit("after pomodoroController.start")
        LaunchTrace.emit("before reminderController.start")
        reminderController.start()
        LaunchTrace.emit("after reminderController.start")
        LaunchTrace.emit("ProductivityApplicationController.start end")
    }

    func stop() {
        notificationDeliveryMonitor.stop()
        reactionCoordinator.stop()
        timerController.stop()
        pomodoroController.stop()
        reminderController.stop()
    }

    private func toggleCharacterReactions() {
        let isEnabled = !reactionCoordinator.isEnabled
        reactionCoordinator.setReactionsEnabled(isEnabled)
        menuController.setProductivityCharacterReactionsEnabled(isEnabled)
    }
}
