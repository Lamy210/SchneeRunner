import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityNotificationRuntimeTests: XCTestCase {
    func testBareExecutableRuntimeDoesNotCreateSystemNotificationClient() async throws {
        var didCreateSystemClient = false
        let scheduler = ProductivityNotificationScheduler(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner"),
            systemClientFactory: {
                didCreateSystemClient = true
                return FakeUnavailableNotificationCenterClient()
            }
        )

        let timer = try ProductivityCountdownTimer(
            title: "Smoke",
            duration: 60,
            now: Date()
        )
        let status = try await scheduler.scheduleTimer(timer, now: Date())

        XCTAssertFalse(didCreateSystemClient)
        XCTAssertEqual(status, .disabled)
    }

    func testApplicationBundleRuntimeCreatesSystemNotificationClient() {
        var didCreateSystemClient = false
        _ = ProductivityNotificationScheduler(
            bundleIdentifier: "io.github.Lamy210.SchneeRunner",
            bundleURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app"),
            systemClientFactory: {
                didCreateSystemClient = true
                return FakeUnavailableNotificationCenterClient()
            }
        )

        XCTAssertTrue(didCreateSystemClient)
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

@MainActor
private final class FakeUnavailableNotificationCenterClient: ProductivityNotificationCenterClient {
    func currentAuthorizationState() async -> NotificationAuthorizationState {
        .denied
    }

    func requestAuthorization() async throws -> Bool {
        false
    }

    func pendingIdentifiers() async -> Set<String> {
        []
    }

    func add(_: ProductivityNotificationRequest) async throws {}

    func removePending(identifiers _: Set<String>) {}
}
