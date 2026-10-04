import AppKit
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class AnimationControllerTests: XCTestCase {
    func testAnimationAdvancesWhileEventTrackingRunLoopModeIsActive() {
        let controller = AnimationController()
        let frames = [
            NSImage(size: NSSize(width: 1, height: 1)),
            NSImage(size: NSSize(width: 1, height: 1))
        ]
        var renderedFrameCount = 0

        controller.onFrame = { _ in
            renderedFrameCount += 1
        }
        controller.replaceFrames(frames)
        defer {
            controller.stop()
        }

        let deadline = Date().addingTimeInterval(0.25)
        while renderedFrameCount < 2, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertGreaterThanOrEqual(renderedFrameCount, 2)
    }

    func testCPUAdaptivePaceUsesReferenceRateWhenUnavailable() {
        let controller = AnimationController()
        controller.setFramesPerSecond(24)

        controller.setCPUAdaptivePace(nil)

        XCTAssertEqual(controller.framesPerSecond, 12)
        XCTAssertEqual(controller.playbackRate, 1)
    }

    func testCPUAdaptivePaceUsesSampledRateWhenAvailable() {
        let controller = AnimationController()

        controller.setCPUAdaptivePace(.sprint)

        XCTAssertEqual(
            controller.framesPerSecond,
            AnimationPace.sprint.framesPerSecond
        )
    }
}
