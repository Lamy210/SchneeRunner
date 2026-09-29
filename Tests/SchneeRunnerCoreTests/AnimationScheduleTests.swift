@testable import SchneeRunnerCore
import XCTest

final class AnimationScheduleTests: XCTestCase {
    func testUniformScheduleUsesRequestedFPS() throws {
        let schedule = try AnimationSchedule.uniform(
            frameCount: 3,
            framesPerSecond: 20
        )

        XCTAssertEqual(schedule.frameCount, 3)
        XCTAssertEqual(schedule.totalDuration, 0.15, accuracy: 0.000_1)
        XCTAssertEqual(
            try XCTUnwrap(schedule.duration(at: 1)),
            0.05,
            accuracy: 0.000_1
        )
    }

    func testAuthoredDurationsArePreserved() throws {
        let schedule = try AnimationSchedule(
            frameDurations: [0.04, 0.12, 0.08]
        )

        XCTAssertEqual(
            schedule.frameDurations,
            [0.04, 0.12, 0.08]
        )
    }

    func testScalesAuthoredDurationsByPlaybackRate() throws {
        let schedule = try AnimationSchedule(
            frameDurations: [0.1, 0.2]
        )

        let scaled = try schedule.scaled(by: 2)

        XCTAssertEqual(
            scaled.frameDurations,
            [0.05, 0.1]
        )
    }

    func testRejectsInvalidPlaybackRate() throws {
        let schedule = try AnimationSchedule(
            frameDurations: [0.1]
        )

        XCTAssertThrowsError(
            try schedule.scaled(by: 0)
        ) { error in
            XCTAssertEqual(
                error as? AnimationScheduleError,
                .invalidPlaybackRate(0)
            )
        }
    }

    func testRejectsInvalidFPS() {
        XCTAssertThrowsError(
            try AnimationSchedule.uniform(
                frameCount: 2,
                framesPerSecond: 0
            )
        ) { error in
            XCTAssertEqual(
                error as? AnimationScheduleError,
                .invalidFramesPerSecond(0)
            )
        }
    }

    func testRejectsNonPositiveAuthoredDuration() {
        XCTAssertThrowsError(
            try AnimationSchedule(
                frameDurations: [0.1, 0]
            )
        ) { error in
            XCTAssertEqual(
                error as? AnimationScheduleError,
                .invalidFrameDuration(
                    index: 1,
                    duration: 0
                )
            )
        }
    }

    func testOutOfBoundsDurationReturnsNil() throws {
        let schedule = try AnimationSchedule(
            frameDurations: [0.1]
        )

        XCTAssertNil(schedule.duration(at: 1))
    }
}
