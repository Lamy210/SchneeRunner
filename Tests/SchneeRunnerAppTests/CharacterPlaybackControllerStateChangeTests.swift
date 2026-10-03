import AppKit
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class CharacterPlaybackStateTests: XCTestCase {
    func testNotifiesAfterInstallResolvesState() throws {
        let controller = CharacterPlaybackController(
            animationController: AnimationController()
        )
        var notifications = 0
        controller.onStateChange = {
            notifications += 1
        }

        try controller.install(makeRunOnlyLibrary())

        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(controller.requestedState, .run)
        XCTAssertEqual(controller.resolvedState, .run)
    }

    func testNotifiesWhenRequestedStateChangesButFallbackDoesNot() throws {
        let controller = CharacterPlaybackController(
            animationController: AnimationController()
        )
        try controller.install(makeRunOnlyLibrary())

        var observedStates: [(CharacterState, CharacterState?)] = []
        controller.onStateChange = {
            observedStates.append(
                (controller.requestedState, controller.resolvedState)
            )
        }

        controller.requestState(.sprint)
        controller.requestState(.dash)

        XCTAssertEqual(observedStates.count, 2)
        XCTAssertEqual(observedStates[0].0, .sprint)
        XCTAssertEqual(observedStates[0].1, .run)
        XCTAssertEqual(observedStates[1].0, .dash)
        XCTAssertEqual(observedStates[1].1, .run)
    }

    func testDoesNotNotifyForDuplicateRequestedAndResolvedState() throws {
        let controller = CharacterPlaybackController(
            animationController: AnimationController()
        )
        try controller.install(makeRunOnlyLibrary())

        var notifications = 0
        controller.onStateChange = {
            notifications += 1
        }

        controller.requestState(.run)

        XCTAssertEqual(notifications, 0)
    }

    private func makeRunOnlyLibrary() throws -> CharacterAnimationLibrary {
        let animation = try LoadedAnimation.uniform(
            frames: [NSImage(size: NSSize(width: 1, height: 1))]
        )
        return try CharacterAnimationLibrary(
            animations: [.run: animation],
            defaultState: .run
        )
    }
}
