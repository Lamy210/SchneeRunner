import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class CharacterPackLoaderTests: XCTestCase {
    func testLoadsMixedStateClipsAndResolvesFallback() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        try prepareMixedStatePack(fixture)
        let library = try CharacterPackLoader().load(
            from: fixture.packageURL
        )

        assertMixedStateLibrary(library)
    }

    func testLoadsSpriteSheetClip() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let spriteURL = fixture.packageURL
            .appendingPathComponent("run.png")
        try writeTestPNG(
            width: 8,
            height: 4,
            to: spriteURL
        )
        try writePackManifest(
            CharacterPackManifest(
                name: "Sprite Runner",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .run,
                        kind: .spriteSheet4x2,
                        path: "run.png"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        let library = try CharacterPackLoader().load(
            from: fixture.packageURL
        )

        XCTAssertEqual(
            library.availableStates,
            [.run]
        )
        XCTAssertEqual(
            library.resolve(requestedState: .run)
                .animation.frames.count,
            8
        )
    }
}

private extension CharacterPackLoaderTests {
    func prepareMixedStatePack(
        _ fixture: PackFixture
    ) throws {
        let idleURL = fixture.packageURL
            .appendingPathComponent("idle.gif")
        try writeTestGIF(to: idleURL)

        let walkURL = fixture.packageURL
            .appendingPathComponent("walk.png")
        try writeTestPNG(to: walkURL)

        let runDirectory = fixture.packageURL
            .appendingPathComponent("run", isDirectory: true)
        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )
        try writeTestPNG(
            to: runDirectory.appendingPathComponent("frame1.png")
        )
        try writeTestPNG(
            to: runDirectory.appendingPathComponent("frame2.png")
        )

        try writePackManifest(
            CharacterPackManifest(
                name: "Test Runner",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .idle,
                        kind: .gif,
                        path: "idle.gif"
                    ),
                    CharacterPackClip(
                        state: .walk,
                        kind: .singleImage,
                        path: "walk.png"
                    ),
                    CharacterPackClip(
                        state: .run,
                        kind: .pngSequence,
                        path: "run"
                    )
                ]
            ),
            to: fixture.packageURL
        )
    }

    private func assertMixedStateLibrary(
        _ library: CharacterAnimationLibrary
    ) {
        XCTAssertEqual(
            library.availableStates,
            [.idle, .walk, .run]
        )
        XCTAssertEqual(
            library.resolve(requestedState: .idle).resolvedState,
            .idle
        )
        XCTAssertEqual(
            library.resolve(requestedState: .sprint).resolvedState,
            .run
        )
    }
}
