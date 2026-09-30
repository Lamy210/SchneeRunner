@testable import SchneeRunnerCore
import XCTest

final class CharacterPackAnimatedImageClipTests: XCTestCase {
    func testLoaderPreservesAPNGAndWebPTiming() throws {
        let fixture = try makePackFixture()
        defer {
            fixture.cleanup()
        }

        let idleURL = fixture.packageURL
            .appendingPathComponent("idle.png")
        let runURL = fixture.packageURL
            .appendingPathComponent("run.webp")
        try writeTestAPNG(to: idleURL)
        try writeTestWebP(to: runURL)
        try writePackManifest(
            CharacterPackManifest(
                name: "Animated Pack",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .idle,
                        kind: .apng,
                        path: "idle.png"
                    ),
                    CharacterPackClip(
                        state: .run,
                        kind: .webP,
                        path: "run.webp"
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
            [.idle, .run]
        )
        XCTAssertEqual(
            library.resolve(requestedState: .idle)
                .animation.schedule.frameDurations[0],
            0.05,
            accuracy: 0.01
        )
        XCTAssertEqual(
            library.resolve(requestedState: .run)
                .animation.schedule.frameDurations[1],
            0.2,
            accuracy: 0.01
        )
    }

    func testBuilderCanonicalizesAPNGAndWebPClips() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        let idleURL = rootURL.appendingPathComponent("idle.apng")
        let runURL = rootURL.appendingPathComponent("run.webp")
        let destinationURL = rootURL.appendingPathComponent(
            "Animated.schneerunner",
            isDirectory: true
        )
        try writeTestAPNG(to: idleURL)
        try writeTestWebP(to: runURL)

        try CharacterPackBuilder().build(
            CharacterPackBuildRequest(
                name: "Animated Pack",
                defaultState: .run,
                clips: [
                    CharacterPackBuildClip(
                        state: .run,
                        kind: .webP,
                        sourceURL: runURL
                    ),
                    CharacterPackBuildClip(
                        state: .idle,
                        kind: .apng,
                        sourceURL: idleURL
                    )
                ]
            ),
            at: destinationURL
        )

        let loader = CharacterPackLoader()
        let manifest = try loader.validatedManifest(
            from: destinationURL
        )

        XCTAssertEqual(
            manifest.clips.map(\.state),
            [.idle, .run]
        )
        XCTAssertEqual(
            manifest.clips.map(\.kind),
            [.apng, .webP]
        )
        XCTAssertEqual(
            manifest.clips.map(\.path),
            [
                "clips/idle/source.png",
                "clips/run/source.webp"
            ]
        )

        let library = try loader.load(
            from: destinationURL
        )
        XCTAssertEqual(
            library.availableStates,
            [.idle, .run]
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: idleURL.path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: runURL.path
            )
        )
    }
}
