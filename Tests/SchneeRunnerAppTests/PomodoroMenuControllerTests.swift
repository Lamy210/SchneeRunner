import AppKit
import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroMenuControllerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testIdleMenuOffersStartWithDefaultConfiguration() throws {
        let controller = PomodoroMenuController()
        var configuration: PomodoroConfiguration?
        controller.onStart = { configuration = $0 }

        let menu = try XCTUnwrap(controller.rootItem.submenu)
        let startItem = try XCTUnwrap(menu.item(withTitle: "Start Pomodoro"))
        perform(startItem)

        let selected = try XCTUnwrap(configuration)
        XCTAssertEqual(selected.focusDuration, 25 * 60)
        XCTAssertEqual(selected.shortBreakDuration, 5 * 60)
        XCTAssertEqual(selected.longBreakDuration, 15 * 60)
        XCTAssertEqual(selected.focusPhasesBeforeLongBreak, 4)
        XCTAssertFalse(selected.autoStartNextPhase)
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
        perform(try XCTUnwrap(menu.item(withTitle: "Pause")))
        perform(try XCTUnwrap(menu.item(withTitle: "Stop")))

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
        perform(try XCTUnwrap(menu.item(withTitle: "Resume")))

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
        perform(try XCTUnwrap(menu.item(withTitle: "Start Break")))

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
