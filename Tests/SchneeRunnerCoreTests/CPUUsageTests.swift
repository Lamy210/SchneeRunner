@testable import SchneeRunnerCore
import XCTest

final class CPUUsageTests: XCTestCase {
    func testFirstSnapshotDoesNotProduceUtilization() {
        var calculator = CPUUsageCalculator()

        let utilization = calculator.utilization(
            for: CPUTickSnapshot(
                user: 10,
                system: 5,
                idle: 85,
                nice: 0
            )
        )

        XCTAssertNil(utilization)
    }

    func testCalculatesBusyShareFromTickDeltas() throws {
        var calculator = CPUUsageCalculator()

        _ = calculator.utilization(
            for: CPUTickSnapshot(
                user: 100,
                system: 50,
                idle: 850,
                nice: 0
            )
        )

        let utilization = try XCTUnwrap(
            calculator.utilization(
                for: CPUTickSnapshot(
                    user: 130,
                    system: 60,
                    idle: 910,
                    nice: 0
                )
            )
        )

        XCTAssertEqual(utilization, 0.4, accuracy: 0.000_1)
    }

    func testCounterRegressionResetsSamplingWindow() {
        var calculator = CPUUsageCalculator()

        _ = calculator.utilization(
            for: CPUTickSnapshot(
                user: 100,
                system: 100,
                idle: 100,
                nice: 100
            )
        )

        XCTAssertNil(
            calculator.utilization(
                for: CPUTickSnapshot(
                    user: 10,
                    system: 10,
                    idle: 10,
                    nice: 10
                )
            )
        )
    }

    func testExponentialMovingAverageSmoothsSamples() {
        var average = ExponentialMovingAverage(alpha: 0.25)

        XCTAssertEqual(average.add(0.2), 0.2, accuracy: 0.000_1)
        XCTAssertEqual(average.add(1), 0.4, accuracy: 0.000_1)
        XCTAssertEqual(average.add(0), 0.3, accuracy: 0.000_1)
    }
}
