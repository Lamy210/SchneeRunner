@testable import SchneeRunnerCore
import XCTest

final class DesktopMotionPolicyTests: XCTestCase {
    func testMovesRightWithinVisibleRange() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: 100
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 20,
                    direction: .right
                ),
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: 0.05
            ),
            DesktopMotionState(
                x: 25,
                direction: .right
            )
        )
    }

    func testMovesLeftWithinVisibleRange() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: 100
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 20,
                    direction: .left
                ),
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: 0.05
            ),
            DesktopMotionState(
                x: 15,
                direction: .left
            )
        )
    }

    func testReflectsAtRightEdge() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: 100
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 198,
                    direction: .right
                ),
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: 0.05
            ),
            DesktopMotionState(
                x: 197,
                direction: .left
            )
        )
    }

    func testReflectsAcrossMultipleEdges() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: 1000
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 5,
                    direction: .right
                ),
                windowWidth: 80,
                visibleMinX: 0,
                visibleMaxX: 100,
                elapsedSeconds: 0.1
            ),
            DesktopMotionState(
                x: 15,
                direction: .left
            )
        )
    }

    func testCapsLongElapsedInterval() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: 100
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 20,
                    direction: .right
                ),
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: 1
            ),
            DesktopMotionState(
                x: 30,
                direction: .right
            )
        )
    }

    func testNegativeElapsedDoesNotMoveWithinRange() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: 100
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 20,
                    direction: .right
                ),
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: -1
            ),
            DesktopMotionState(
                x: 20,
                direction: .right
            )
        )
    }

    func testNonFiniteElapsedLeavesStateUnchanged() {
        let policy = DesktopMotionPolicy()
        let state = DesktopMotionState(
            x: 20,
            direction: .right
        )

        XCTAssertEqual(
            policy.advance(
                state: state,
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: .infinity
            ),
            state
        )
    }

    func testInvalidSpeedFallsBackToDefaultSpeed() {
        let policy = DesktopMotionPolicy(
            speedPointsPerSecond: .nan
        )

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 20,
                    direction: .right
                ),
                windowWidth: 100,
                visibleMinX: 0,
                visibleMaxX: 300,
                elapsedSeconds: 0.1
            ),
            DesktopMotionState(
                x: 27.2,
                direction: .right
            )
        )
    }

    func testWindowWiderThanVisibleRangePinsToMinimumX() {
        let policy = DesktopMotionPolicy()

        XCTAssertEqual(
            policy.advance(
                state: DesktopMotionState(
                    x: 120,
                    direction: .left
                ),
                windowWidth: 400,
                visibleMinX: 50,
                visibleMaxX: 300,
                elapsedSeconds: 0.05
            ),
            DesktopMotionState(
                x: 50,
                direction: .left
            )
        )
    }

    func testInvalidGeometryLeavesStateUnchanged() {
        let policy = DesktopMotionPolicy()
        let state = DesktopMotionState(
            x: 20,
            direction: .right
        )

        XCTAssertEqual(
            policy.advance(
                state: state,
                windowWidth: 100,
                visibleMinX: 300,
                visibleMaxX: 0,
                elapsedSeconds: 0.05
            ),
            state
        )
    }
}
