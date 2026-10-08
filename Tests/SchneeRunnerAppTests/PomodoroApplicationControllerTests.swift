import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class PomodoroApplicationControllerTests: XCTestCase {
    func testStopCancelsInFlightLaunchReconciliation() async throws {
        let center = DelayedPomodoroNotificationCenter(
            addDelayNanoseconds: 100_000_000
        )
        let fixture = try makeFixture(center: center)
        defer { fixture.cleanup() }

        fixture.controller.start()
        for _ in 0 ..< 100 where !center.addStarted {
            await Task.yield()
        }
        XCTAssertTrue(center.addStarted)

        fixture.controller.stop()
        try await Task<Never, Never>.sleep(nanoseconds: 150_000_000)

        XCTAssertTrue(center.addWasCancelled)
        XCTAssertFalse(center.addCompleted)
    }

    private func makeFixture(
        center: DelayedPomodoroNotificationCenter
    ) throws -> PomodoroApplicationFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let now = Date()
        let session = try PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: now
        )
        let stateStore = ProductivityStateStore(
            baseDirectory: baseDirectory,
            fileManager: .default
        )
        try stateStore.save(ProductivitySnapshot(pomodoro: session))
        let suiteName = "PomodoroApplicationControllerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let menuController = StatusMenuController()
        let scheduler = ProductivityNotificationScheduler(center: center)
        let controller = PomodoroApplicationController(
            menuController: menuController,
            baseDirectory: baseDirectory,
            fileManager: .default,
            defaults: defaults,
            notificationScheduler: scheduler
        )
        return PomodoroApplicationFixture(
            baseDirectory: baseDirectory,
            defaultsSuiteName: suiteName,
            controller: controller
        )
    }
}

@MainActor
private final class DelayedPomodoroNotificationCenter: ProductivityNotificationCenterClient {
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

private struct PomodoroApplicationFixture {
    let baseDirectory: URL
    let defaultsSuiteName: String
    let controller: PomodoroApplicationController

    func cleanup() {
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
