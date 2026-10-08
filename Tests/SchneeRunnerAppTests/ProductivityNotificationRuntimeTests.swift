import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityNotificationRuntimeTests: XCTestCase {
    func testBareExecutableRuntimeDisablesSystemNotificationClient() async throws {
        let client = SystemProductivityNotificationClient(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner")
        )
        let scheduler = ProductivityNotificationScheduler(center: client)

        let timer = try ProductivityCountdownTimer(
            title: "Smoke",
            duration: 60,
            now: Date()
        )
        let status = try await scheduler.scheduleTimer(timer, now: Date())

        XCTAssertEqual(status, .disabled)
    }

    func testApplicationBundleRuntimeEnablesSystemNotificationPolicy() {
        XCTAssertTrue(
            SystemNotificationRuntime.isAvailable(
                bundleIdentifier: "io.github.Lamy210.SchneeRunner",
                bundleURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app")
            )
        )
    }

    func testBareExecutableRuntimeDoesNotStartNotificationDeliveryMonitor() {
        let monitor = ProductivityNotificationDeliveryMonitor()

        let didStart = monitor.start(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner")
        )

        XCTAssertFalse(didStart)
    }
}
