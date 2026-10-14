import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class LocalBuildEventMonitorTests: XCTestCase {
    func testReceivedBuildEventIsForwardedWithoutCharacterStateMapping() {
        let monitor = LocalBuildEventMonitor()
        let input = LocalBuildEvent(phase: .succeeded)
        var events: [BuildLifecycleProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.process(input)

        XCTAssertEqual(events, [.received(input)])
    }

    func testExpiryFiresWhileEventTrackingRunLoopModeIsActive() {
        let monitor = LocalBuildEventMonitor()
        var events: [BuildLifecycleProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.scheduleExpiry(after: 0.01)

        let deadline = Date().addingTimeInterval(0.2)
        while events.isEmpty, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertEqual(events, [.expired])
    }

    func testCancellationSuppressesStaleExpiry() {
        let monitor = LocalBuildEventMonitor()
        let cancelled = LocalBuildEvent(phase: .cancelled)
        var events: [BuildLifecycleProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.scheduleExpiry(after: 0.01)
        monitor.process(cancelled)

        RunLoop.main.run(
            mode: .eventTracking,
            before: Date().addingTimeInterval(0.05)
        )

        XCTAssertEqual(events, [.received(cancelled)])
    }
}
