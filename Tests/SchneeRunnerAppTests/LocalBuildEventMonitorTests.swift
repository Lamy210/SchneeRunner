import Foundation
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class LocalBuildEventMonitorTests: XCTestCase {
    func testExpiryFiresWhileEventTrackingRunLoopModeIsActive() {
        let monitor = LocalBuildEventMonitor()
        var didClear = false
        monitor.onClear = {
            didClear = true
        }

        monitor.scheduleExpiry(after: 0.01)

        let deadline = Date().addingTimeInterval(0.2)
        while !didClear, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertTrue(didClear)
    }
}
