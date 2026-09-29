@testable import SchneeRunnerCore
import XCTest

final class AdaptiveAnimationSpeedPolicyTests: XCTestCase {
    func testHighUtilizationCanJumpDirectlyToSprint() {
        var policy = AdaptiveAnimationSpeedPolicy()

        XCTAssertEqual(policy.pace(for: 0.95), .sprint)
        XCTAssertEqual(policy.currentPace.framesPerSecond, 24)
    }

    func testHysteresisPreventsBoundaryFlapping() {
        var policy = AdaptiveAnimationSpeedPolicy()

        XCTAssertEqual(policy.pace(for: 0.50), .run)
        XCTAssertEqual(policy.pace(for: 0.39), .run)
        XCTAssertEqual(policy.pace(for: 0.36), .walk)
    }

    func testUtilizationIsClampedToValidRange() {
        var lowPolicy = AdaptiveAnimationSpeedPolicy()
        var highPolicy = AdaptiveAnimationSpeedPolicy()

        XCTAssertEqual(lowPolicy.pace(for: -1), .idle)
        XCTAssertEqual(highPolicy.pace(for: 2), .sprint)
    }
}
