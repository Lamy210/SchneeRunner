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
        let fixture = try makeBuilderFixture()
        defer {
            fixture.cleanup()
        }

        try CharacterPackBuilder().build(
            animatedBuildRequest(fixture),
            at: fixture.destinationURL
        )

        try assertCanonicalAnimatedBuild(fixture)
    }
}

private extension CharacterPackAnimatedImageClipTests {
    func makeBuilderFixture() throws -> AnimatedBuilderFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        let fixture = AnimatedBuilderFixture(
            rootURL: rootURL,
            idleURL: rootURL.appendingPathComponent("idle.apng"),
            runURL: rootURL.appendingPathComponent("run.webp"),
            destinationURL: rootURL.appendingPathComponent(
                "Animated.schneerunner",
                isDirectory: true
            )
        )
        try writeTestAPNG(to: fixture.idleURL)
        try writeTestWebP(to: fixture.runURL)
        return fixture
    }

    func animatedBuildRequest(
        _ fixture: AnimatedBuilderFixture
    ) -> CharacterPackBuildRequest {
        CharacterPackBuildRequest(
            name: "Animated Pack",
            defaultState: .run,
            clips: [
                CharacterPackBuildClip(
                    state: .run,
                    kind: .webP,
                    sourceURL: fixture.runURL
                ),
                CharacterPackBuildClip(
                    state: .idle,
                    kind: .apng,
                    sourceURL: fixture.idleURL
                )
            ]
        )
    }

    func assertCanonicalAnimatedBuild(
        _ fixture: AnimatedBuilderFixture
    ) throws {
        let loader = CharacterPackLoader()
        let manifest = try loader.validatedManifest(
            from: fixture.destinationURL
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
            from: fixture.destinationURL
        )
        XCTAssertEqual(
            library.availableStates,
            [.idle, .run]
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.idleURL.path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.runURL.path
            )
        )
    }
}

private struct AnimatedBuilderFixture {
    let rootURL: URL
    let idleURL: URL
    let runURL: URL
    let destinationURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(
            at: rootURL
        )
    }
}
