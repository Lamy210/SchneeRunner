@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CPUMonitorRestartStateTests: XCTestCase {
    func testRestartResetsSmoothingAndAdaptivePace() throws {
        var snapshots = [
            CPUTickSnapshot(
                user: 100,
                system: 0,
                idle: 900,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 200,
                system: 0,
                idle: 900,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 210,
                system: 0,
                idle: 990,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 226,
                system: 0,
                idle: 1_074,
                nice: 0
            )
        ]
        let monitor = CPUMonitor(
            snapshotProvider: {
                snapshots.removeFirst()
            }
        )
        var updates: [CPUMonitor.Update] = []
        monitor.onUpdate = { updates.append($0) }

        monitor.start()
        monitor.sampleNow()
        monitor.stop()

        updates.removeAll()
        monitor.start()
        XCTAssertTrue(updates.isEmpty)

        monitor.sampleNow()
        monitor.stop()

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(
            try XCTUnwrap(updates.last).utilization,
            0.16,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            try XCTUnwrap(updates.last).pace,
            .idle
        )
    }
}
