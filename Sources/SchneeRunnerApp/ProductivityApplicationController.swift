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
        notificationScheduler: ProductivityNotificationScheduler? = nil
    ) {
        self.menuController = menuController
        self.notificationDeliveryMonitor = notificationDeliveryMonitor
        let managementWindow = ProductivityManagementWindowController()
        self.managementWindow = managementWindow
        let reactionCoordinator = ProductivityCharacterStateCoordinator(
            characterStateCoordinator: characterStateCoordinator,
            reactionStore: reactionStore
        )
        self.reactionCoordinator = reactionCoordinator
        let notificationScheduler = notificationScheduler ?? ProductivityNotificationScheduler()

        timerController = TimerApplicationController(
            menuController: menuController,
            managementWindow: managementWindow,
            notificationScheduler: notificationScheduler
        )
        pomodoroController = PomodoroApplicationController(
            menuController: menuController,
            managementWindow: managementWindow,
            notificationScheduler: notificationScheduler
        )
        reminderController = ReminderApplicationController(
            menuController: menuController,
            notificationScheduler: notificationScheduler,
            managementWindow: managementWindow
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
        menuController.onToggleProductivityCharacterReactions = { [weak self] in
            self?.toggleCharacterReactions()
        }
        menuController.setProductivityCharacterReactionsEnabled(
            reactionCoordinator.isEnabled
        )
    }

    func start() {
        notificationDeliveryMonitor.start()
        timerController.start()
        pomodoroController.start()
        reminderController.start()
    }

    func stop() {
        notificationDeliveryMonitor.stop()
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
