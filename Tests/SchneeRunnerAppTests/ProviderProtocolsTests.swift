@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProviderProtocolsTests: XCTestCase {
    func testCPUMonitorAdoptsMetricProvider() {
        let concrete = CPUMonitor()
        let provider: any MetricProvider<CPUMonitor.Update> = concrete

        provider.onUpdate = { _ in }

        XCTAssertTrue((provider as AnyObject) === concrete)
    }

    func testBatteryWarningMonitorAdoptsMetricProvider() {
        let concrete = SystemBatteryWarningMonitor()
        let provider: any MetricProvider<BatteryWarningLevel> = concrete

        provider.onUpdate = { _ in }

        XCTAssertTrue((provider as AnyObject) === concrete)
    }

    func testMemoryPressureMonitorAdoptsEventProvider() {
        let concrete = SystemMemoryPressureMonitor()
        let provider: any EventProvider<MemoryPressureLevel> = concrete

        provider.onEvent = { _ in }

        XCTAssertTrue((provider as AnyObject) === concrete)
    }
}
