import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityNotificationRuntimeTests: XCTestCase {
    func testBareExecutableRuntimeDisablesSystemNotificationClient() async throws {
        let now = Date()
        let client = SystemProductivityNotificationClient(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner")
        )
        let scheduler = ProductivityNotificationScheduler(center: client)

        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Smoke",
            duration: 60,
            startedAt: now
        )
        let status = try await scheduler.scheduleTimer(timer, now: now)

        XCTAssertEqual(
            status,
            ProductivityNotificationDeliveryStatus.disabled
        )
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
