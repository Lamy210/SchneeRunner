@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class SystemBatteryWarningMonitorTests: XCTestCase {
    func testRestartPublishesCurrentWarningLevelToReplacementConsumer() {
        let monitor = SystemBatteryWarningMonitor()
        var initialUpdates: [BatteryWarningLevel] = []
        monitor.onUpdate = { initialUpdates.append($0) }

        monitor.start()
        monitor.stop()

        XCTAssertEqual(initialUpdates.count, 1)

        var restartedUpdates: [BatteryWarningLevel] = []
        monitor.onUpdate = { restartedUpdates.append($0) }

        monitor.start()
        monitor.stop()

        XCTAssertEqual(restartedUpdates.count, 1)
    }
}
