@MainActor
final class ProductivityApplicationController {
    private let timerController: TimerApplicationController
    private let pomodoroController: PomodoroApplicationController
    private let reminderController: ReminderApplicationController

    init(menuController: StatusMenuController) {
        timerController = TimerApplicationController(
            menuController: menuController
        )
        pomodoroController = PomodoroApplicationController(
            menuController: menuController
        )
        reminderController = ReminderApplicationController(
            menuController: menuController
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
}
