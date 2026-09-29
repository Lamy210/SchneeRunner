import AppKit
@testable import SchneeRunnerCore
import XCTest

final class LoadedAnimationTests: XCTestCase {
    func testUniformAnimationBuildsMatchingSchedule() throws {
        let frames = [
            NSImage(size: NSSize(width: 1, height: 1)),
            NSImage(size: NSSize(width: 1, height: 1))
        ]

        let animation = try LoadedAnimation.uniform(
            frames: frames,
            framesPerSecond: 10
        )

        XCTAssertEqual(animation.frames.count, 2)
        XCTAssertEqual(
            animation.schedule.frameDurations,
            [0.1, 0.1]
        )
    }

    func testRejectsFrameScheduleCountMismatch() throws {
        let schedule = try AnimationSchedule(
            frameDurations: [0.1, 0.1]
        )

        XCTAssertThrowsError(
            try LoadedAnimation(
                frames: [
                    NSImage(size: NSSize(width: 1, height: 1))
                ],
                schedule: schedule
            )
        ) { error in
            XCTAssertEqual(
                error as? LoadedAnimationError,
                .frameCountMismatch(
                    images: 1,
                    schedule: 2
                )
            )
        }
    }
}
