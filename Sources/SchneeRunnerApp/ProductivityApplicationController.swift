@MainActor
final class ProductivityApplicationController {
    private let managementWindow: ProductivityManagementWindowController
    private let timerController: TimerApplicationController
    private let pomodoroController: PomodoroApplicationController
    private let reminderController: ReminderApplicationController

    init(menuController: StatusMenuController) {
        let managementWindow = ProductivityManagementWindowController()
        self.managementWindow = managementWindow
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
