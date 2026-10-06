import SchneeRunnerCore

@MainActor
final class ProductivityApplicationController {
    private let menuController: StatusMenuController
    private let managementWindow: ProductivityManagementWindowController
    private let timerController: TimerApplicationController
    private let pomodoroController: PomodoroApplicationController
    private let reminderController: ReminderApplicationController
    private let reactionCoordinator: ProductivityCharacterStateCoordinator

    init(
        menuController: StatusMenuController,
        characterStateCoordinator: CharacterStateCoordinator,
        reactionStore: ProductivityCharacterReactionStore = .init()
    ) {
        self.menuController = menuController
        let managementWindow = ProductivityManagementWindowController()
        self.managementWindow = managementWindow
        let reactionCoordinator = ProductivityCharacterStateCoordinator(
            characterStateCoordinator: characterStateCoordinator,
            reactionStore: reactionStore
        )
        self.reactionCoordinator = reactionCoordinator

        timerController = TimerApplicationController(
            menuController: menuController,
            managementWindow: managementWindow
        )
        pomodoroController = PomodoroApplicationController(
            menuController: menuController,
            managementWindow: managementWindow
        )
        reminderController = ReminderApplicationController(
            menuController: menuController,
            managementWindow: managementWindow
        )

        timerController.onTimersChanged = { [weak reactionCoordinator] timers, now in
            reactionCoordinator?.updateTimers(timers, now: now)
        }
        pomodoroController.onSessionChanged = { [weak reactionCoordinator] session, now in
            reactionCoordinator?.updatePomodoro(session, now: now)
        }
        menuController.onToggleProductivityCharacterReactions = { [weak self] in
            self?.toggleCharacterReactions()
        }
        menuController.setProductivityCharacterReactionsEnabled(
            reactionCoordinator.isEnabled
        )
    }

    func start() {
        timerController.start()
        pomodoroController.start()
        reminderController.start()
    }

    func stop() {
        timerController.stop()
        pomodoroController.stop()
        reminderController.stop()
    }

    func recordReminderFired() {
        reactionCoordinator.recordReminderFired()
    }

    private func toggleCharacterReactions() {
        let isEnabled = !reactionCoordinator.isEnabled
        reactionCoordinator.setReactionsEnabled(isEnabled)
        menuController.setProductivityCharacterReactionsEnabled(isEnabled)
    }
}
