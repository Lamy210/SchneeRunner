@testable import SchneeRunnerCore
import XCTest

final class CharacterStateTests: XCTestCase {
    func testCPUAnimationPacesMapToEquivalentCharacterStates() {
        let policy = CharacterStatePolicy()
        let mappings: [(AnimationPace, CharacterState)] = [
            (.idle, .idle),
            (.walk, .walk),
            (.run, .run),
            (.dash, .dash),
            (.sprint, .sprint)
        ]

        for (pace, expectedState) in mappings {
            XCTAssertEqual(
                policy.state(for: pace),
                expectedState
            )
        }
    }

    func testDisplayNamesAreStableForMenuPresentation() {
        XCTAssertEqual(CharacterState.idle.displayName, "Idle")
        XCTAssertEqual(CharacterState.walk.displayName, "Walk")
        XCTAssertEqual(CharacterState.run.displayName, "Run")
        XCTAssertEqual(CharacterState.dash.displayName, "Dash")
        XCTAssertEqual(CharacterState.sprint.displayName, "Sprint")
    }
}
