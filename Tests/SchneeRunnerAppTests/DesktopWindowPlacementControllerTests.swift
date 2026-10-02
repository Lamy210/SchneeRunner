import AppKit
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class DesktopWindowPlacementControllerTests: XCTestCase {
    func testConstrainedFrameStaysSquareWhenWidthLimitsAvailableSize() {
        let controller = DesktopWindowPlacementController()

        let constrained = controller.constrainedFrame(
            NSRect(
                x: 250,
                y: 200,
                width: 512,
                height: 512
            ),
            to: NSRect(
                x: 100,
                y: 50,
                width: 300,
                height: 700
            )
        )

        XCTAssertEqual(
            constrained,
            NSRect(
                x: 100,
                y: 200,
                width: 300,
                height: 300
            )
        )
    }

    func testConstrainedFrameClampsOriginInsideVisibleFrame() {
        let controller = DesktopWindowPlacementController()

        let constrained = controller.constrainedFrame(
            NSRect(
                x: -100,
                y: 900,
                width: 128,
                height: 128
            ),
            to: NSRect(
                x: 10,
                y: 20,
                width: 500,
                height: 400
            )
        )

        XCTAssertEqual(
            constrained,
            NSRect(
                x: 10,
                y: 292,
                width: 128,
                height: 128
            )
        )
    }

    func testConstrainedFrameCanonicalizesNearSquareInput() {
        let controller = DesktopWindowPlacementController()

        let constrained = controller.constrainedFrame(
            NSRect(
                x: 50,
                y: 50,
                width: 128,
                height: 128.4
            ),
            to: NSRect(
                x: 0,
                y: 0,
                width: 800,
                height: 600
            )
        )

        XCTAssertEqual(constrained.width, 128.4)
        XCTAssertEqual(constrained.height, 128.4)
    }

    func testInvalidVisibleFrameLeavesInputUnchanged() {
        let controller = DesktopWindowPlacementController()
        let frame = NSRect(
            x: 50,
            y: 50,
            width: 128,
            height: 128
        )

        XCTAssertEqual(
            controller.constrainedFrame(
                frame,
                to: NSRect(
                    x: 0,
                    y: 0,
                    width: 0,
                    height: 600
                )
            ),
            frame
        )
    }
}
