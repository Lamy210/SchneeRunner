@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

final class CharacterStateStatusFormatterTests: XCTestCase {
    func testShowsRequestedStateWhenResolutionMatches() {
        XCTAssertEqual(
            CharacterStateStatusFormatter.label(
                requestedState: .run,
                resolvedState: .run
            ),
            "Run"
        )
    }

    func testShowsFallbackTransitionWhenResolvedStateDiffers() {
        XCTAssertEqual(
            CharacterStateStatusFormatter.label(
                requestedState: .sprint,
                resolvedState: .run
            ),
            "Sprint → Run"
        )
    }

    func testShowsRequestedStateBeforeAnAnimationIsResolved() {
        XCTAssertEqual(
            CharacterStateStatusFormatter.label(
                requestedState: .walk,
                resolvedState: nil
            ),
            "Walk"
        )
    }
}
