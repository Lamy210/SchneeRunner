import AppKit
import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroMenuControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testIdleMenuUsesConfiguredDefaultsAndOffersSettings() throws {
        let controller = PomodoroMenuController()
        let configured = try PomodoroConfiguration(
            focusDuration: 50 * 60,
            shortBreakDuration: 10 * 60,
            longBreakDuration: 30 * 60,
            focusPhasesBeforeLongBreak: 3,
            autoStartNextPhase: true
        )
        var configuration: PomodoroConfiguration?
        var settingsCount = 0
        controller.onStart = { configuration = $0 }
        controller.onSettings = { settingsCount += 1 }
        controller.setConfiguration(configured)

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        perform(try XCTUnwrap(menu.item(withTitle: "Start Pomodoro")))
        perform(try XCTUnwrap(menu.item(withTitle: "Settings…")))

        XCTAssertEqual(configuration, configured)
        XCTAssertEqual(settingsCount, 1)
    }

    func testRunningFocusShowsRemainingTimeAndDispatchesPauseAndStop() throws {
        let controller = PomodoroMenuController()
        let session = try makeSession()
        var pauseCount = 0
        var stopCount = 0
        controller.onPause = { pauseCount += 1 }
        controller.onStop = { stopCount += 1 }

        controller.setSession(
            session,
            now: now.addingTimeInterval(60)
        )

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        XCTAssertNotNil(menu.item(withTitle: "Focus · 24:00"))
        let pauseItem = try XCTUnwrap(menu.item(withTitle: "Pause"))
        let stopItem = try XCTUnwrap(menu.item(withTitle: "Stop"))
        perform(pauseItem)
        perform(stopItem)

        XCTAssertEqual(pauseCount, 1)
        XCTAssertEqual(stopCount, 1)
    }

    func testPausedFocusShowsPausedRemainingAndDispatchesResume() throws {
        let controller = PomodoroMenuController()
        let session = try makeSession().pausing(
            at: now.addingTimeInterval(120)
        )
        var resumeCount = 0
        controller.onResume = { resumeCount += 1 }

        controller.setSession(
            session,
            now: now.addingTimeInterval(600)
        )

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        XCTAssertNotNil(menu.item(withTitle: "Focus · Paused 23:00"))
        let resumeItem = try XCTUnwrap(menu.item(withTitle: "Resume"))
        perform(resumeItem)

        XCTAssertEqual(resumeCount, 1)
    }

    func testWaitingBreakOffersStartBreakAction() throws {
        let controller = PomodoroMenuController()
        let session = try makeSession().advancing(
            at: now.addingTimeInterval(25 * 60)
        )
        var startPhaseCount = 0
        controller.onStartCurrentPhase = { startPhaseCount += 1 }

        controller.setSession(
            session,
            now: now.addingTimeInterval(25 * 60)
        )

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        XCTAssertNotNil(menu.item(withTitle: "Short Break · Ready"))
        let startBreakItem = try XCTUnwrap(
            menu.item(withTitle: "Start Break")
        )
        perform(startBreakItem)

        XCTAssertEqual(startPhaseCount, 1)
    }

    private func makeSession() throws -> PomodoroSession {
        try PomodoroSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            configuration: PomodoroConfiguration(),
            startedAt: now
        )
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
