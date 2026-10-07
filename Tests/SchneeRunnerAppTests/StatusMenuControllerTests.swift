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

    func testTimerManageCallbackIsForwarded() throws {
        let controller = StatusMenuController()
        var manageCount = 0
        controller.onManageTimers = { manageCount += 1 }
        let timersMenu = try XCTUnwrap(
            controller.menu.item(withTitle: "Timers")?.submenu
        )

        try perform(XCTUnwrap(timersMenu.item(withTitle: "Manage Timers…")))

        XCTAssertEqual(manageCount, 1)
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

    func testPomodoroSettingsCallbackIsForwarded() throws {
        let controller = StatusMenuController()
        var settingsCount = 0
        controller.onPomodoroSettings = { settingsCount += 1 }
        let pomodoroMenu = try XCTUnwrap(
            controller.menu.item(withTitle: "Pomodoro")?.submenu
        )

        try perform(XCTUnwrap(pomodoroMenu.item(withTitle: "Settings…")))

        XCTAssertEqual(settingsCount, 1)
    }

    func testStatusMenuContainsSingleRemindersSubmenu() {
        let controller = StatusMenuController()

        XCTAssertEqual(
            controller.menu.items.filter { $0.title == "Reminders" }.count,
            1
        )
        XCTAssertNotNil(
            controller.menu.item(withTitle: "Reminders")?.submenu
        )
    }

    func testReminderCallbacksAreForwarded() throws {
        let controller = StatusMenuController()
        var newCount = 0
        var manageCount = 0
        controller.onNewReminder = { newCount += 1 }
        controller.onManageReminders = { manageCount += 1 }
        let remindersMenu = try XCTUnwrap(
            controller.menu.item(withTitle: "Reminders")?.submenu
        )

        try perform(XCTUnwrap(remindersMenu.item(withTitle: "New Reminder…")))
        try perform(XCTUnwrap(remindersMenu.item(withTitle: "Manage Reminders…")))

        XCTAssertEqual(newCount, 1)
        XCTAssertEqual(manageCount, 1)
    }

    func testProductivityReactionToggleDefaultsOnAndForwardsCallback() throws {
        let controller = StatusMenuController()
        var toggleCount = 0
        controller.onToggleProductivityCharacterReactions = {
            toggleCount += 1
        }
        let item = try XCTUnwrap(
            controller.menu.item(withTitle: "Productivity Character Reactions")
        )

        XCTAssertEqual(item.state, .on)
        perform(item)

        XCTAssertEqual(toggleCount, 1)
    }

    func testProductivityReactionToggleReflectsPersistedState() throws {
        let controller = StatusMenuController()
        let item = try XCTUnwrap(
            controller.menu.item(withTitle: "Productivity Character Reactions")
        )

        controller.setProductivityCharacterReactionsEnabled(false)
        XCTAssertEqual(item.state, .off)

        controller.setProductivityCharacterReactionsEnabled(true)
        XCTAssertEqual(item.state, .on)
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
