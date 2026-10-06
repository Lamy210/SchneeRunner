import AppKit
import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerMenuControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testNewTimerMenuContainsRequiredPresetsAndCustomEntry() throws {
        let controller = TimerMenuController()
        let newTimerMenu = try XCTUnwrap(
            controller.rootItem.submenu?.item(withTitle: "New Timer")?.submenu
        )

        XCTAssertEqual(
            newTimerMenu.items.map(\.title),
            ["5 min", "10 min", "15 min", "25 min", "30 min", "60 min", "Custom…"]
        )
    }

    func testPresetAndCustomActionsDispatchCallbacks() throws {
        let controller = TimerMenuController()
        var selectedDuration: TimeInterval?
        var customCount = 0
        controller.onStartPreset = { duration in
            selectedDuration = duration
        }
        controller.onStartCustomTimer = {
            customCount += 1
        }
        let newTimerMenu = try XCTUnwrap(
            controller.rootItem.submenu?.item(withTitle: "New Timer")?.submenu
        )

        let twentyFive = try XCTUnwrap(newTimerMenu.item(withTitle: "25 min"))
        perform(twentyFive)
        try perform(XCTUnwrap(newTimerMenu.item(withTitle: "Custom…")))

        XCTAssertEqual(selectedDuration, 25 * 60)
        XCTAssertEqual(customCount, 1)
    }

    func testRunningTimerRowShowsRemainingTimeAndDispatchesPauseAndCancel() throws {
        let controller = TimerMenuController()
        let timer = try makeTimer(title: "Focus", duration: 1500)
        var pausedID: UUID?
        var cancelledID: UUID?
        controller.onPauseTimer = { pausedID = $0 }
        controller.onCancelTimer = { cancelledID = $0 }

        controller.setTimers(
            [timer],
            now: now.addingTimeInterval(60)
        )

        let timerItem = try activeTimerItem(in: controller, id: timer.id)
        XCTAssertEqual(timerItem.title, "Focus · 24:00")
        let actions = try XCTUnwrap(timerItem.submenu)
        try perform(XCTUnwrap(actions.item(withTitle: "Pause")))
        try perform(XCTUnwrap(actions.item(withTitle: "Cancel")))

        XCTAssertEqual(pausedID, timer.id)
        XCTAssertEqual(cancelledID, timer.id)
    }

    func testPausedTimerRowDispatchesResume() throws {
        let controller = TimerMenuController()
        let timer = try makeTimer(title: "Break", duration: 600)
            .pausing(at: now.addingTimeInterval(120))
        var resumedID: UUID?
        controller.onResumeTimer = { resumedID = $0 }

        controller.setTimers([timer], now: now.addingTimeInterval(300))

        let timerItem = try activeTimerItem(in: controller, id: timer.id)
        XCTAssertEqual(timerItem.title, "Break · Paused 08:00")
        let actions = try XCTUnwrap(timerItem.submenu)
        try perform(XCTUnwrap(actions.item(withTitle: "Resume")))

        XCTAssertEqual(resumedID, timer.id)
    }

    func testCompletedAndCancelledTimersAreNotShownAsActiveRows() throws {
        let controller = TimerMenuController()
        let running = try makeTimer(title: "Running", duration: 600)
        let completed = running.reconciling(
            at: now.addingTimeInterval(601)
        )
        let cancelled = try makeTimer(title: "Cancelled", duration: 600)
            .cancelling()

        controller.setTimers(
            [completed, cancelled],
            now: now.addingTimeInterval(601)
        )

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        XCTAssertNotNil(menu.item(withTitle: "No active timers"))
        XCTAssertNil(activeTimerItemIfPresent(in: controller, id: completed.id))
        XCTAssertNil(activeTimerItemIfPresent(in: controller, id: cancelled.id))
    }

    private func makeTimer(
        title: String,
        duration: TimeInterval
    ) throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(),
            title: title,
            duration: duration,
            startedAt: now
        )
    }

    private func activeTimerItem(
        in controller: TimerMenuController,
        id: UUID
    ) throws -> NSMenuItem {
        try XCTUnwrap(activeTimerItemIfPresent(in: controller, id: id))
    }

    private func activeTimerItemIfPresent(
        in controller: TimerMenuController,
        id: UUID
    ) -> NSMenuItem? {
        controller.rootItem.submenu?.items.first {
            $0.representedObject as? String == id.uuidString
        }
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
