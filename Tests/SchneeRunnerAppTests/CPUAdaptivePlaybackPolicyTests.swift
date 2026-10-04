@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

final class CPUAdaptivePlaybackPolicyTests: XCTestCase {
    func testUsesReferenceRateWhenCPUUpdateIsUnavailable() {
        XCTAssertEqual(
            CPUAdaptivePlaybackPolicy.framesPerSecond(for: nil),
            AnimationPace.run.framesPerSecond
        )
    }

    func testUsesSampledPaceWhenCPUUpdateIsAvailable() {
        XCTAssertEqual(
            CPUAdaptivePlaybackPolicy.framesPerSecond(for: .sprint),
            AnimationPace.sprint.framesPerSecond
        )
    }
}
