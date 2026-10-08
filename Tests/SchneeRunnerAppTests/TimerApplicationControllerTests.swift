import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class TimerApplicationControllerTests: XCTestCase {
    func testStopCancelsInFlightLaunchReconciliation() async throws {
        let center = DelayedTimerNotificationCenter(
            addDelayNanoseconds: 100_000_000
        )
        let fixture = try makeFixture(center: center)
        defer { fixture.cleanup() }
        var observedChanges = 0
        fixture.controller.onTimersChanged = { _, _ in
            observedChanges += 1
        }

        fixture.controller.start()
        for _ in 0 ..< 100 where !center.addStarted {
            await Task.yield()
        }
        XCTAssertTrue(center.addStarted)

        fixture.controller.stop()
        try await Task<Never, Never>.sleep(nanoseconds: 150_000_000)

        XCTAssertTrue(center.addWasCancelled)
        XCTAssertFalse(center.addCompleted)
        XCTAssertEqual(observedChanges, 0)
    }

    private func makeFixture(
        center: DelayedTimerNotificationCenter
    ) throws -> TimerApplicationFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let now = Date()
        let timer = try ProductivityCountdownTimer(
            id: UUID(),
            title: "Launch reconcile",
            duration: 3600,
            startedAt: now
        )
        let stateStore = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        try stateStore.save(ProductivitySnapshot(timers: [timer]))
        let menuController = StatusMenuController()
        let scheduler = ProductivityNotificationScheduler(center: center)
        let controller = TimerApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            notificationScheduler: scheduler
        )
        return TimerApplicationFixture(
            baseDirectory: baseDirectory,
            controller: controller
        )
    }
}

@MainActor
private final class DelayedTimerNotificationCenter: ProductivityNotificationCenterClient {
    private let addDelayNanoseconds: UInt64

    private(set) var addStarted = false
    private(set) var addCompleted = false
    private(set) var addWasCancelled = false

    init(addDelayNanoseconds: UInt64) {
        self.addDelayNanoseconds = addDelayNanoseconds
    }

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        .authorized
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func pendingIdentifiers() async -> Set<String> {
        []
    }

    func add(_: ProductivityNotificationRequest) async throws {
        addStarted = true
        do {
            try await Task<Never, Never>.sleep(
                nanoseconds: addDelayNanoseconds
            )
        } catch {
            if error is CancellationError {
                addWasCancelled = true
            }
            throw error
        }
        addCompleted = true
    }

    func removePending(identifiers _: Set<String>) {}
}

private struct TimerApplicationFixture {
    let baseDirectory: URL
    let controller: TimerApplicationController

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
