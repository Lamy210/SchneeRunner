@testable import SchneeRunnerCore
import XCTest

final class ProductivitySnapshotPomodoroTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testPomodoroRoundTripsWithCurrentSchema() throws {
        let pomodoro = try makePomodoro()
        let snapshot = ProductivitySnapshot(pomodoro: pomodoro)

        let decoded = try JSONDecoder().decode(
            ProductivitySnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
    }

    func testLegacySnapshotWithoutPomodoroDecodesAsNil() throws {
        let data = Data(#"{"schemaVersion":1,"timers":[],"reminders":[]}"#.utf8)

        let decoded = try JSONDecoder().decode(
            ProductivitySnapshot.self,
            from: data
        )

        XCTAssertNil(decoded.pomodoro)
    }

    func testReplacingTimersPreservesPomodoroAndReminders() throws {
        let pomodoro = try makePomodoro()
        let reminder = try makeReminder()
        let timer = try makeTimer()
        let snapshot = ProductivitySnapshot(
            reminders: [reminder],
            pomodoro: pomodoro
        )

        let updated = snapshot.replacingTimers([timer])

        XCTAssertEqual(updated.timers, [timer])
        XCTAssertEqual(updated.reminders, [reminder])
        XCTAssertEqual(updated.pomodoro, pomodoro)
    }

    func testReplacingPomodoroPreservesTimersAndReminders() throws {
        let timer = try makeTimer()
        let reminder = try makeReminder()
        let pomodoro = try makePomodoro()
        let snapshot = ProductivitySnapshot(
            timers: [timer],
            reminders: [reminder]
        )

        let updated = snapshot.replacingPomodoro(pomodoro)

        XCTAssertEqual(updated.timers, [timer])
        XCTAssertEqual(updated.reminders, [reminder])
        XCTAssertEqual(updated.pomodoro, pomodoro)
    }

    func testReconciliationAdvancesPomodoroWithoutChangingOtherSlices() throws {
        let timer = try makeTimer()
        let reminder = try makeReminder()
        let pomodoro = try makePomodoro()
        let snapshot = ProductivitySnapshot(
            timers: [timer],
            reminders: [reminder],
            pomodoro: pomodoro
        )
        let now = start.addingTimeInterval(25 * 60)

        let reconciled = snapshot.reconciling(at: now)

        XCTAssertEqual(reconciled.timers, [timer.reconciling(at: now)])
        XCTAssertEqual(reconciled.reminders, [reminder])
        XCTAssertEqual(reconciled.pomodoro?.currentPhase, .shortBreak)
        XCTAssertEqual(reconciled.pomodoro?.state, .waiting)
    }

    private func makeTimer() throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Timer",
            duration: 60 * 60,
            startedAt: start
        )
    }

    private func makePomodoro() throws -> PomodoroSession {
        try PomodoroSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
    }

    private func makeReminder() throws -> ProductivityReminder {
        try ProductivityReminder(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Reminder",
            body: nil,
            enabled: true,
            schedule: .daily(hour: 9, minute: 0),
            createdAt: start,
            updatedAt: start
        )
    }
}
