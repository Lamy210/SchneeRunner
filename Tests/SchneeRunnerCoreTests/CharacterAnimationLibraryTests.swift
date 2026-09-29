import AppKit
@testable import SchneeRunnerCore
import XCTest

final class CharacterAnimationLibraryTests: XCTestCase {
    func testResolvesExactStateWhenAnimationExists() throws {
        let idle = try animation(frameCount: 1)
        let run = try animation(frameCount: 2)
        let library = try CharacterAnimationLibrary(
            animations: [
                .idle: idle,
                .run: run
            ],
            defaultState: .run
        )

        let resolution = library.resolve(
            requestedState: .idle
        )

        XCTAssertEqual(resolution.requestedState, .idle)
        XCTAssertEqual(resolution.resolvedState, .idle)
        XCTAssertFalse(resolution.usedFallback)
        XCTAssertEqual(resolution.animation.frames.count, 1)
    }

    func testFallsBackToDefaultStateWhenAnimationIsMissing() throws {
        let run = try animation(frameCount: 2)
        let library = try CharacterAnimationLibrary.single(
            animation: run,
            state: .run
        )

        let resolution = library.resolve(
            requestedState: .sprint
        )

        XCTAssertEqual(resolution.requestedState, .sprint)
        XCTAssertEqual(resolution.resolvedState, .run)
        XCTAssertTrue(resolution.usedFallback)
        XCTAssertEqual(resolution.animation.frames.count, 2)
    }

    func testAvailableStatesFollowCanonicalStateOrder() throws {
        let library = try CharacterAnimationLibrary(
            animations: [
                .sprint: try animation(frameCount: 1),
                .idle: try animation(frameCount: 1),
                .run: try animation(frameCount: 1)
            ],
            defaultState: .run
        )

        XCTAssertEqual(
            library.availableStates,
            [.idle, .run, .sprint]
        )
    }

    func testRejectsEmptyLibrary() {
        XCTAssertThrowsError(
            try CharacterAnimationLibrary(
                animations: [:],
                defaultState: .run
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterAnimationLibraryError,
                .emptyLibrary
            )
        }
    }

    func testRejectsMissingDefaultState() throws {
        let idle = try animation(frameCount: 1)

        XCTAssertThrowsError(
            try CharacterAnimationLibrary(
                animations: [.idle: idle],
                defaultState: .run
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterAnimationLibraryError,
                .defaultStateMissing(.run)
            )
        }
    }

    private func animation(
        frameCount: Int
    ) throws -> LoadedAnimation {
        let frames = (0 ..< frameCount).map { _ in
            NSImage(size: NSSize(width: 1, height: 1))
        }

        return try LoadedAnimation.uniform(
            frames: frames
        )
    }
}
