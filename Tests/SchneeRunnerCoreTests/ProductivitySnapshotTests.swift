import Foundation
@testable import SchneeRunnerCore
import XCTest

final class ProductivitySnapshotTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testCurrentVersionRoundTrips() throws {
        let snapshot = try ProductivitySnapshot(
            timers: [makeTimer(duration: 1500)]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ProductivitySnapshot.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, ProductivitySnapshot.currentSchemaVersion)
        XCTAssertEqual(decoded, snapshot)
    }

    func testDecodeRejectsUnsupportedSchemaVersion() throws {
        let snapshot = ProductivitySnapshot(timers: [])
        let data = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["schemaVersion"] = ProductivitySnapshot.currentSchemaVersion + 1
        let unsupported = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try JSONDecoder().decode(ProductivitySnapshot.self, from: unsupported)
        ) { error in
            XCTAssertEqual(
                error as? ProductivitySnapshotError,
                .unsupportedSchemaVersion(ProductivitySnapshot.currentSchemaVersion + 1)
            )
        }
    }

    func testReconcileCompletesOverdueTimerOnce() throws {
        let snapshot = try ProductivitySnapshot(
            timers: [makeTimer(duration: 10)]
        )
        let now = start.addingTimeInterval(11)

        let reconciled = snapshot.reconciling(at: now)
        let timer = try XCTUnwrap(reconciled.timers.first)

        XCTAssertEqual(timer.state, .completed)
        XCTAssertEqual(timer.completedAt, start.addingTimeInterval(10))
    }

    func testSecondReconciliationIsIdempotent() throws {
        let snapshot = try ProductivitySnapshot(
            timers: [makeTimer(duration: 10)]
        )
        let now = start.addingTimeInterval(11)

        let once = snapshot.reconciling(at: now)
        let twice = once.reconciling(at: now.addingTimeInterval(60))

        XCTAssertEqual(twice, once)
    }

    func testReminderRoundTripsInCurrentSnapshot() throws {
        let reminder = try makeReminder()
        let snapshot = ProductivitySnapshot(reminders: [reminder])

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ProductivitySnapshot.self, from: data)

        XCTAssertEqual(decoded.reminders, [reminder])
    }

    func testLegacySnapshotWithoutRemindersDecodesEmptyCollection() throws {
        let data = Data("""
        {"schemaVersion":1,"timers":[]}
        """.utf8)

        let decoded = try JSONDecoder().decode(ProductivitySnapshot.self, from: data)

        XCTAssertEqual(decoded.reminders, [])
    }

    private func makeTimer(duration: TimeInterval) throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(),
            title: "Focus",
            duration: duration,
            startedAt: start
        )
    }

    private func makeReminder() throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Standup",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: start,
            updatedAt: start
        )
    }
}
