import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityNotificationSchedulerTests: XCTestCase {
    func testTimerIdentifierUsesStableLowercaseUUID() throws {
        let id = try XCTUnwrap(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )

        XCTAssertEqual(
            ProductivityNotificationScheduler.timerIdentifier(for: id),
            "schneerunner.timer.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        )
    }

    func testSynchronizeReplacesSameLogicalTimerRequest() async throws {
        let center = FakeProductivityNotificationCenterClient()
        center.authorizationState = .authorized
        let timer = try makeTimer()
        let identifier = ProductivityNotificationScheduler.timerIdentifier(for: timer.id)
        center.pending = [identifier]
        let scheduler = ProductivityNotificationScheduler(center: center)

        let result = try await scheduler.reconcileTimers(
            [timer],
            now: start
        )

        XCTAssertEqual(result, .scheduled)
        XCTAssertEqual(center.addedRequests.map(\.identifier), [identifier])
        XCTAssertTrue(center.removedIdentifiers.isEmpty)
    }

    func testSynchronizePreservesForeignPendingIdentifiers() async throws {
        let center = FakeProductivityNotificationCenterClient()
        center.authorizationState = .authorized
        center.pending = [
            "schneerunner.timer.11111111-1111-1111-1111-111111111111",
            "com.example.foreign"
        ]
        let scheduler = ProductivityNotificationScheduler(center: center)

        _ = try await scheduler.reconcileTimers([], now: start)

        XCTAssertEqual(
            center.removedIdentifiers,
            ["schneerunner.timer.11111111-1111-1111-1111-111111111111"]
        )
        XCTAssertFalse(center.removedIdentifiers.contains("com.example.foreign"))
    }

    func testDeniedAuthorizationReturnsDisabledWithoutMutation() async throws {
        let center = FakeProductivityNotificationCenterClient()
        center.authorizationState = .denied
        center.pending = ["com.example.foreign"]
        let scheduler = ProductivityNotificationScheduler(center: center)
        let timer = try makeTimer()

        let result = try await scheduler.reconcileTimers(
            [timer],
            now: start
        )

        XCTAssertEqual(result, .disabled)
        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertTrue(center.removedIdentifiers.isEmpty)
        XCTAssertEqual(center.requestAuthorizationCount, 0)
    }

    func testPomodoroIdentifierUsesStableSessionAndPhase() throws {
        let id = try XCTUnwrap(
            UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        )

        XCTAssertEqual(
            ProductivityNotificationScheduler.pomodoroIdentifier(
                for: id,
                phase: .shortBreak
            ),
            "schneerunner.pomodoro.aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.shortBreak"
        )
    }

    func testPomodoroReconcileReplacesOwnedPhaseAndPreservesOtherNotifications() async throws {
        let center = FakeProductivityNotificationCenterClient()
        center.authorizationState = .authorized
        let session = try makePomodoro()
        let staleIdentifier = ProductivityNotificationScheduler.pomodoroIdentifier(
            for: session.id,
            phase: .shortBreak
        )
        let desiredIdentifier = ProductivityNotificationScheduler.pomodoroIdentifier(
            for: session.id,
            phase: .focus
        )
        center.pending = [
            staleIdentifier,
            "schneerunner.timer.11111111-1111-1111-1111-111111111111",
            "com.example.foreign"
        ]
        let scheduler = ProductivityNotificationScheduler(center: center)

        let result = try await scheduler.reconcilePomodoro(
            session,
            now: start
        )

        XCTAssertEqual(result, .scheduled)
        XCTAssertEqual(center.removedIdentifiers, [staleIdentifier])
        XCTAssertEqual(
            center.addedRequests.map(\.identifier),
            [desiredIdentifier]
        )
        XCTAssertFalse(
            center.removedIdentifiers.contains(
                "schneerunner.timer.11111111-1111-1111-1111-111111111111"
            )
        )
        XCTAssertFalse(center.removedIdentifiers.contains("com.example.foreign"))
    }

    private var start: Date {
        Date(timeIntervalSince1970: 1_791_331_200)
    }

    private func makeTimer() throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Focus",
            duration: 1500,
            startedAt: start
        )
    }

    private func makePomodoro() throws -> PomodoroSession {
        try PomodoroSession(
            id: XCTUnwrap(
                UUID(uuidString: "22222222-2222-2222-2222-222222222222")
            ),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
    }
}

@MainActor
private final class FakeProductivityNotificationCenterClient: ProductivityNotificationCenterClient {
    var authorizationState: NotificationAuthorizationState = .notDetermined
    var pending: Set<String> = []
    var addedRequests: [ProductivityNotificationRequest] = []
    var removedIdentifiers: Set<String> = []
    var requestAuthorizationResult = true
    var requestAuthorizationCount = 0

    func currentAuthorizationState() async -> NotificationAuthorizationState {
        authorizationState
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCount += 1
        return requestAuthorizationResult
    }

    func pendingIdentifiers() async -> Set<String> {
        pending
    }

    func add(_ request: ProductivityNotificationRequest) async throws {
        addedRequests.append(request)
        pending.insert(request.identifier)
    }

    func removePending(identifiers: Set<String>) {
        removedIdentifiers.formUnion(identifiers)
        pending.subtract(identifiers)
    }
}
