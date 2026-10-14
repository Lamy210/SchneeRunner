import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class LocalCharacterStateEventMonitorTests: XCTestCase {
    func testSetEventIsForwardedWithoutTriggerMapping() throws {
        let monitor = LocalCharacterStateEventMonitor()
        let input = try LocalCharacterStateEvent.set(
            state: .dash,
            channel: "ci"
        )
        var events: [LocalCharacterStateProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.process(input)

        XCTAssertEqual(events, [.received(input)])
    }

    func testClearEventIsForwardedAndCancelsPendingExpiry() throws {
        let monitor = LocalCharacterStateEventMonitor()
        let set = try LocalCharacterStateEvent.set(
            state: .sprint,
            durationSeconds: 0.1,
            channel: "ci"
        )
        let clear = try LocalCharacterStateEvent.clear(channel: "ci")
        var events: [LocalCharacterStateProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.process(set)
        monitor.process(clear)

        RunLoop.main.run(
            mode: .eventTracking,
            before: Date().addingTimeInterval(0.15)
        )

        XCTAssertEqual(events, [.received(set), .received(clear)])
    }

    func testExpiryEmitsOnlyAddressedChannel() throws {
        let monitor = LocalCharacterStateEventMonitor()
        let fast = try LocalCharacterStateEvent.set(
            state: .dash,
            durationSeconds: 0.1,
            channel: "fast"
        )
        let slow = try LocalCharacterStateEvent.set(
            state: .sprint,
            durationSeconds: 0.3,
            channel: "slow"
        )
        var events: [LocalCharacterStateProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.process(fast)
        monitor.process(slow)

        let deadline = Date().addingTimeInterval(0.2)
        while !events.contains(.expired(channel: "fast")), Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertEqual(
            events,
            [
                .received(fast),
                .received(slow),
                .expired(channel: "fast"),
            ]
        )
    }

    func testReplacingChannelTimerSuppressesStaleExpiry() throws {
        let monitor = LocalCharacterStateEventMonitor()
        let first = try LocalCharacterStateEvent.set(
            state: .dash,
            durationSeconds: 0.1,
            channel: "ci"
        )
        let replacement = try LocalCharacterStateEvent.set(
            state: .sprint,
            durationSeconds: 0.3,
            channel: "ci"
        )
        var events: [LocalCharacterStateProviderEvent] = []
        monitor.onEvent = { events.append($0) }

        monitor.process(first)
        monitor.process(replacement)

        RunLoop.main.run(
            mode: .eventTracking,
            before: Date().addingTimeInterval(0.15)
        )

        XCTAssertEqual(events, [.received(first), .received(replacement)])
    }
}
