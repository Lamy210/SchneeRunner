import AppKit
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class DesktopCharacterMotionControllerTests: XCTestCase {
    func testAutomaticMovementContinuesWhileEventTrackingRunLoopModeIsActive() throws {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let renderer = DesktopCharacterRenderer(
            placementStore: DesktopCharacterPlacementStore(
                defaults: defaults
            )
        )
        renderer.render(
            NSImage(
                size: NSSize(width: 1, height: 1)
            )
        )
        renderer.setVisible(true)

        let controller = DesktopCharacterMotionController(
            renderer: renderer,
            policy: DesktopMotionPolicy(
                speedPointsPerSecond: 120
            )
        )
        defer {
            controller.stop()
            renderer.stop()
        }

        let initialX = try XCTUnwrap(renderer.motionGeometry).originX
        controller.setEnabled(true)
        XCTAssertTrue(controller.isEnabled)

        let deadline = Date().addingTimeInterval(0.25)
        while Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        let finalX = try XCTUnwrap(renderer.motionGeometry).originX
        XCTAssertNotEqual(finalX, initialX)
    }
}
