@testable import SchneeRunnerApp
import XCTest

final class DesktopMovePersistencePolicyTests: XCTestCase {
    func testUserDragDefersPersistenceDuringAutomaticMovement() {
        XCTAssertEqual(
            DesktopMovePersistencePolicy.action(
                isApplyingManagedFrame: false,
                isUserInteracting: true,
                isAutonomousMovementActive: true
            ),
            .deferUntilInteractionEnds
        )
    }

    func testProgrammaticAutomaticMovementDoesNotPersist() {
        XCTAssertEqual(
            DesktopMovePersistencePolicy.action(
                isApplyingManagedFrame: false,
                isUserInteracting: false,
                isAutonomousMovementActive: true
            ),
            .ignore
        )
    }

    func testManualMovePersistsImmediatelyOutsideInteraction() {
        XCTAssertEqual(
            DesktopMovePersistencePolicy.action(
                isApplyingManagedFrame: false,
                isUserInteracting: false,
                isAutonomousMovementActive: false
            ),
            .persistNow
        )
    }

    func testManagedFrameMoveDoesNotPersist() {
        XCTAssertEqual(
            DesktopMovePersistencePolicy.action(
                isApplyingManagedFrame: true,
                isUserInteracting: true,
                isAutonomousMovementActive: false
            ),
            .ignore
        )
    }

    func testDeferredMovePersistsWhenPointerInteractionEnds() {
        XCTAssertTrue(
            DesktopMovePersistencePolicy.shouldPersistDeferredMove(
                wasInteracting: true,
                isInteracting: false,
                isMovePersistenceDeferred: true,
                isLiveResizing: false
            )
        )
    }

    func testLiveResizeOwnsFinalPersistence() {
        XCTAssertFalse(
            DesktopMovePersistencePolicy.shouldPersistDeferredMove(
                wasInteracting: true,
                isInteracting: false,
                isMovePersistenceDeferred: true,
                isLiveResizing: true
            )
        )
    }
}
