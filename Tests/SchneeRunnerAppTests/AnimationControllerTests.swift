import AppKit
@testable import SchneeRunnerApp
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
}
