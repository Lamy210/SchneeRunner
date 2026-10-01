@testable import SchneeRunnerCore
import XCTest

final class LocalBuildEventTests: XCTestCase {
    func testAllPhasesRoundTripThroughJSON() throws {
        for phase in BuildLifecyclePhase.allCases {
            let event = LocalBuildEvent(phase: phase)

            XCTAssertEqual(
                try LocalBuildEvent.decodeJSON(
                    event.encodedJSON()
                ),
                event
            )
        }
    }

    func testBuildStatePolicyMapsLifecycleToEffects() {
        let policy = BuildStatePolicy()

        XCTAssertEqual(
            policy.effect(for: .started),
            BuildTriggerEffect(
                state: .dash,
                durationSeconds: nil
            )
        )
        XCTAssertEqual(
            policy.effect(for: .succeeded),
            BuildTriggerEffect(
                state: .sprint,
                durationSeconds: 2
            )
        )
        XCTAssertEqual(
            policy.effect(for: .failed),
            BuildTriggerEffect(
                state: .idle,
                durationSeconds: 5
            )
        )
        XCTAssertEqual(
            policy.effect(for: .cancelled),
            BuildTriggerEffect(
                state: nil,
                durationSeconds: nil
            )
        )
    }
}
