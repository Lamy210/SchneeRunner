import Foundation
@testable import SchneeRunnerApp
import UserNotifications
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

    func testSchedulingSameLogicalTimerReplacesPendingRequest() async throws {
        let center = FakeProductivityUserNotificationCenter(
            authorizationStatus: .authorized
        )
        let scheduler = ProductivityNotificationScheduler(center: center)
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_791_331_200)

        let first = await scheduler.scheduleTimer(
            id: id,
            title: "First",
            deadline: now.addingTimeInterval(60),
            now: now
        )
        let second = await scheduler.scheduleTimer(
            id: id,
            title: "Second",
            deadline: now.addingTimeInterval(120),
            now: now
        )

        XCTAssertEqual(first, .scheduled)
        XCTAssertEqual(second, .scheduled)
        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.values.first?.content.title, "Second")
    }

    func testCancelTimerPreservesUnrelatedPendingRequest() async {
        let center = FakeProductivityUserNotificationCenter(
            authorizationStatus: .authorized
        )
        center.requests["com.example.foreign"] = UNNotificationRequest(
            identifier: "com.example.foreign",
            content: UNMutableNotificationContent(),
            trigger: nil
        )
        let scheduler = ProductivityNotificationScheduler(center: center)
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_791_331_200)
        _ = await scheduler.scheduleTimer(
            id: id,
            title: "Timer",
            deadline: now.addingTimeInterval(60),
            now: now
        )

        scheduler.cancelTimer(id: id)

        XCTAssertEqual(Set(center.requests.keys), ["com.example.foreign"])
    }

    func testDeniedAuthorizationReturnsDegradedResult() async {
        let center = FakeProductivityUserNotificationCenter(
            authorizationStatus: .denied
        )
        let scheduler = ProductivityNotificationScheduler(center: center)
        let now = Date(timeIntervalSince1970: 1_791_331_200)

        let result = await scheduler.scheduleTimer(
            id: UUID(),
            title: "Timer",
            deadline: now.addingTimeInterval(60),
            now: now
        )

        XCTAssertEqual(result, .authorizationDenied)
        XCTAssertTrue(center.requests.isEmpty)
    }
}

@MainActor
private final class FakeProductivityUserNotificationCenter: ProductivityUserNotificationCenter {
    var authorizationStatusValue: UNAuthorizationStatus
    var authorizationRequestResult = true
    var requests: [String: UNNotificationRequest] = [:]

    init(authorizationStatus: UNAuthorizationStatus) {
        authorizationStatusValue = authorizationStatus
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests[request.identifier] = request
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers {
            requests.removeValue(forKey: identifier)
        }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        Array(requests.values)
    }
}
