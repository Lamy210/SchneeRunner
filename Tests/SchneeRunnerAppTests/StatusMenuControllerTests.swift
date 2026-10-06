import AppKit
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class StatusMenuControllerTests: XCTestCase {
    func testMenuOpenRequestsRecentCharactersRefresh() {
        let controller = StatusMenuController()
        var refreshCount = 0

        controller.onRefreshRecentCharacters = {
            refreshCount += 1
        }

        controller.menuWillOpen(controller.menu)
        controller.menuWillOpen(controller.menu)

        XCTAssertEqual(refreshCount, 2)
    }

    func testStatusMenuContainsSingleTimersSubmenu() {
        let controller = StatusMenuController()

        XCTAssertEqual(
            controller.menu.items.filter { $0.title == "Timers" }.count,
            1
        )
        XCTAssertNotNil(
            controller.menu.item(withTitle: "Timers")?.submenu
        )
    }

    func testTimerPresetCallbackIsForwarded() throws {
        let controller = StatusMenuController()
        var selectedDuration: TimeInterval?
        controller.onStartTimerPreset = { selectedDuration = $0 }
        let timersMenu = try XCTUnwrap(
            controller.menu.item(withTitle: "Timers")?.submenu
        )
        let newTimerMenu = try XCTUnwrap(
            timersMenu.item(withTitle: "New Timer")?.submenu
        )
        let item = try XCTUnwrap(newTimerMenu.item(withTitle: "5 min"))

        perform(item)

        XCTAssertEqual(selectedDuration, 5 * 60)
    }

    func testStatusMenuContainsSinglePomodoroSubmenu() {
        let controller = StatusMenuController()

        XCTAssertEqual(
            controller.menu.items.filter { $0.title == "Pomodoro" }.count,
            1
        )
        XCTAssertNotNil(
            controller.menu.item(withTitle: "Pomodoro")?.submenu
        )
    }

    func testPomodoroStartCallbackIsForwarded() throws {
        let controller = StatusMenuController()
        var startCount = 0
        controller.onStartPomodoro = { _ in startCount += 1 }
        let pomodoroMenu = try XCTUnwrap(
            controller.menu.item(withTitle: "Pomodoro")?.submenu
        )
        let item = try XCTUnwrap(
            pomodoroMenu.item(withTitle: "Start Pomodoro")
        )

        perform(item)

        XCTAssertEqual(startCount, 1)
    }

    private func perform(_ item: NSMenuItem) {
        guard
            let action = item.action,
            let target = item.target as? NSObject
        else {
            XCTFail("Menu item has no target/action")
            return
        }
        _ = target.perform(action, with: item)
    }
}
