@testable import SchneeRunnerCore
import XCTest

final class ReminderSnoozeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_331_200)

    func testSnapshotRoundTripPreservesPersistedSnoozeCollection() throws {
        let snapshotData = try JSONEncoder().encode(ProductivitySnapshot())
        var snapshotObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: snapshotData) as? [String: Any]
        )
        let snooze = SnoozeFixture(
            id: UUID(),
            reminderID: UUID(),
            title: "Standup",
            body: "Join the team call",
            fireDate: now.addingTimeInterval(15 * 60)
        )
        snapshotObject["snoozes"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode([snooze])
        )
        let persistedData = try JSONSerialization.data(
            withJSONObject: snapshotObject
        )

        let decoded = try JSONDecoder().decode(
            ProductivitySnapshot.self,
            from: persistedData
        )
        let roundTripData = try JSONEncoder().encode(decoded)
        let roundTripObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: roundTripData) as? [String: Any]
        )
        let snoozes = roundTripObject["snoozes"] as? [[String: Any]]

        XCTAssertEqual(snoozes?.count, 1)
    }

    func testSnapshotReconciliationDropsExpiredSnoozes() {
        let expired = ReminderSnooze(
            id: UUID(),
            reminderID: UUID(),
            title: "Expired",
            body: nil,
            fireDate: now.addingTimeInterval(-1)
        )
        let future = ReminderSnooze(
            id: UUID(),
            reminderID: UUID(),
            title: "Future",
            body: nil,
            fireDate: now.addingTimeInterval(60)
        )
        let snapshot = ProductivitySnapshot(
            snoozes: [expired, future]
        )

        let reconciled = snapshot.reconciling(at: now)

        XCTAssertEqual(reconciled.snoozes, [future])
    }
}

private struct SnoozeFixture: Codable {
    let id: UUID
    let reminderID: UUID
    let title: String
    let body: String?
    let fireDate: Date
}
