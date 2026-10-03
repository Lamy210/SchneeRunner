@testable import SchneeRunnerApp
import XCTest

final class DesktopPointerInteractionPolicyTests: XCTestCase {
    func testEndsInteractionWhenPrimaryButtonIsNoLongerPressed() {
        XCTAssertTrue(
            DesktopPointerInteractionPolicy.shouldEndInteraction(
                isUserInteracting: true,
                isPrimaryButtonPressed: false
            )
        )
    }

    func testKeepsInteractionWhilePrimaryButtonRemainsPressed() {
        XCTAssertFalse(
            DesktopPointerInteractionPolicy.shouldEndInteraction(
                isUserInteracting: true,
                isPrimaryButtonPressed: true
            )
        )
    }

    func testDoesNothingWhenInteractionIsAlreadyInactive() {
        XCTAssertFalse(
            DesktopPointerInteractionPolicy.shouldEndInteraction(
                isUserInteracting: false,
                isPrimaryButtonPressed: false
            )
        )
    }
}
