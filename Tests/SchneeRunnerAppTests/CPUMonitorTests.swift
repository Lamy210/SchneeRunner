@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CPUMonitorTests: XCTestCase {
    private enum SnapshotError: Error {
        case unavailable
    }

    func testInvalidSampleAfterUpdateReportsErrorWithoutTreatingWarmupAsError() {
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
        var errors: [Error] = []

        monitor.onUpdate = { update in
            updates.append(update)
        }
        monitor.onError = { error in
            errors.append(error)
        }

        monitor.sampleNow()
        XCTAssertTrue(updates.isEmpty)
        XCTAssertTrue(errors.isEmpty)

        monitor.sampleNow()
        XCTAssertEqual(updates.count, 1)
        XCTAssertTrue(errors.isEmpty)

        monitor.sampleNow()
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(
            errors.first as? CPUMonitorError,
            .sampleUnavailable
        )
    }

    func testInvalidSampleResetsSmoothingBeforeNextUpdate() throws {
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
                user: 10,
                system: 10,
                idle: 10,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 10,
                system: 10,
                idle: 110,
                nice: 0
            )
        ]
        let monitor = CPUMonitor(
            snapshotProvider: {
                snapshots.removeFirst()
            }
        )
        var updates: [CPUMonitor.Update] = []

        monitor.onUpdate = { update in
            updates.append(update)
        }

        monitor.sampleNow()
        monitor.sampleNow()
        monitor.sampleNow()
        monitor.sampleNow()

        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(
            try XCTUnwrap(updates.last).utilization,
            0,
            accuracy: 0.000_1
        )
    }

    func testInvalidSampleResetsAdaptivePaceBeforeNextUpdate() throws {
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
                user: 10,
                system: 10,
                idle: 10,
                nice: 0
            ),
            CPUTickSnapshot(
                user: 26,
                system: 10,
                idle: 94,
                nice: 0
            )
        ]
        let monitor = CPUMonitor(
            snapshotProvider: {
                snapshots.removeFirst()
            }
        )
        var updates: [CPUMonitor.Update] = []

        monitor.onUpdate = { update in
            updates.append(update)
        }

        monitor.sampleNow()
        monitor.sampleNow()
        monitor.sampleNow()
        monitor.sampleNow()

        XCTAssertEqual(updates.count, 2)
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

    func testSamplerErrorResetsDerivedStateBeforeNextUpdate() throws {
        var snapshots: [Result<CPUTickSnapshot, SnapshotError>] = [
            .success(
                CPUTickSnapshot(
                    user: 100,
                    system: 0,
                    idle: 900,
                    nice: 0
                )
            ),
            .success(
                CPUTickSnapshot(
                    user: 200,
                    system: 0,
                    idle: 900,
                    nice: 0
                )
            ),
            .failure(.unavailable),
            .success(
                CPUTickSnapshot(
                    user: 216,
                    system: 0,
                    idle: 984,
                    nice: 0
                )
            )
        ]
        let monitor = CPUMonitor(
            snapshotProvider: {
                try snapshots.removeFirst().get()
            }
        )
        var updates: [CPUMonitor.Update] = []
        var errors: [Error] = []

        monitor.onUpdate = { update in
            updates.append(update)
        }
        monitor.onError = { error in
            errors.append(error)
        }

        monitor.sampleNow()
        monitor.sampleNow()
        monitor.sampleNow()
        monitor.sampleNow()

        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(updates.count, 2)
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
