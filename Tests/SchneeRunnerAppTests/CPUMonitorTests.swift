@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CPUMonitorTests: XCTestCase {
    func testInvalidSampleAfterUpdateBecomesUnavailableWithoutTreatingWarmupAsUnavailable() {
        var snapshots = [
            CPUTickSnapshot(
                user: 100,
                system: 100,
                idle: 800,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 130,
                system: 110,
                idle: 860,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 10,
                system: 10,
                idle: 10,
                nice: 0
            )
        ]
        let monitor = CPUMonitor(
            snapshotProvider: {
                snapshots.removeFirst()
            }
        )
        var updates: [CPUMonitor.Update] = []
        var unavailableCount = 0

        monitor.onUpdate = { update in
            updates.append(update)
        }
        monitor.onUnavailable = {
            unavailableCount += 1
        }

        monitor.sampleNow()
        XCTAssertTrue(updates.isEmpty)
        XCTAssertEqual(unavailableCount, 0)

        monitor.sampleNow()
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(unavailableCount, 0)

        monitor.sampleNow()
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(unavailableCount, 1)
    }
}
