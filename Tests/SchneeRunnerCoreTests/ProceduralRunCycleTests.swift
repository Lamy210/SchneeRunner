@testable import SchneeRunnerCore
import XCTest

final class ProceduralRunCycleTests: XCTestCase {
    func testRunCycleContainsEightPositiveScaleFrames() {
        let frames = ProceduralRunCycle.frames

        XCTAssertEqual(frames.count, 8)
        XCTAssertTrue(frames.allSatisfy { $0.horizontalScale > 0 })
        XCTAssertTrue(frames.allSatisfy { $0.verticalScale > 0 })
    }

    func testRunCycleContainsContactCompressionAndAirborneMotion() throws {
        let frames = ProceduralRunCycle.frames
        let minimumLift = try XCTUnwrap(frames.map(\.lift).min())
        let maximumLift = try XCTUnwrap(frames.map(\.lift).max())

        XCTAssertLessThan(minimumLift, 0)
        XCTAssertGreaterThan(maximumLift, 0)
        XCTAssertEqual(frames[0].rotationDegrees, -frames[4].rotationDegrees)
    }
}
