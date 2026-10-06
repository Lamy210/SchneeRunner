import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerMenuDurationBoundaryTests: XCTestCase {
    func testHugeFiniteTimerDurationCanBeRendered() throws {
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Long",
            duration: 1e20,
            startedAt: now
        )
        let controller = TimerMenuController()

        controller.setTimers([timer], now: now)

        let item = try XCTUnwrap(
            controller.rootItem.submenu?.items.first {
                $0.representedObject as? String == timer.id.uuidString
            }
        )
        XCTAssertTrue(item.title.hasPrefix("Long · "))
    }
}
