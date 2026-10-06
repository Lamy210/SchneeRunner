@MainActor
final class ProductivityApplicationController {
    private let timerController: TimerApplicationController
    private let pomodoroController: PomodoroApplicationController

    init(menuController: StatusMenuController) {
        timerController = TimerApplicationController(
            menuController: menuController
        )
        pomodoroController = PomodoroApplicationController(
            menuController: menuController
        )
    }

    func start() {
        timerController.start()
        pomodoroController.start()
    }

    func stop() {
        timerController.stop()
        pomodoroController.stop()
    }
}
