@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CPUMonitorTimerTests: XCTestCase {
    func testSamplingContinuesWhileEventTrackingRunLoopModeIsActive() {
        var sampleCount = 0
        let snapshot = CPUTickSnapshot(
            user: 100,
            system: 100,
            idle: 800,
            nice: 0
        )
        let monitor = CPUMonitor(
            snapshotProvider: {
                sampleCount += 1
                return snapshot
            }
        )

        monitor.start()
        defer {
            monitor.stop()
        }

        let deadline = Date().addingTimeInterval(1.3)
        while sampleCount < 2, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.05)
            )
        }

        XCTAssertGreaterThanOrEqual(sampleCount, 2)
    }
}
