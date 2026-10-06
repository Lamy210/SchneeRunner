import Foundation
@testable import SchneeRunnerCore
import XCTest

final class ProductivitySnapshotPomodoroTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_791_331_200)

    func testPomodoroRoundTripsWithCurrentSchema() throws {
        let pomodoro = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
        let snapshot = ProductivitySnapshot(pomodoro: pomodoro)

        let decoded = try JSONDecoder().decode(
            ProductivitySnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )

        XCTAssertEqual(decoded, snapshot)
    }

    func testLegacySnapshotWithoutPomodoroDecodesAsNil() throws {
        let data = Data(#"{"schemaVersion":1,"timers":[]}"#.utf8)

        let decoded = try JSONDecoder().decode(
            ProductivitySnapshot.self,
            from: data
        )

        XCTAssertNil(decoded.pomodoro)
    }

    func testReplacingTimersPreservesPomodoro() throws {
        let pomodoro = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
        let snapshot = ProductivitySnapshot(pomodoro: pomodoro)
        let timer = try makeTimer()

        let updated = snapshot.replacingTimers([timer])

        XCTAssertEqual(updated.timers, [timer])
        XCTAssertEqual(updated.pomodoro, pomodoro)
    }

    func testReplacingPomodoroPreservesTimers() throws {
        let timer = try makeTimer()
        let pomodoro = PomodoroSession(
            id: UUID(),
            configuration: PomodoroConfiguration(),
            startedAt: start
        )
        let snapshot = ProductivitySnapshot(timers: [timer])

        let updated = snapshot.replacingPomodoro(pomodoro)

        XCTAssertEqual(updated.timers, [timer])
        XCTAssertEqual(updated.pomodoro, pomodoro)
    }

    private func makeTimer() throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(),
            title: "Timer",
            duration: 300,
            startedAt: start
        )
    }
}
