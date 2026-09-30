@testable import SchneeRunnerCore
import XCTest

final class CharacterPackBuilderTests: XCTestCase {
    func testBuildCreatesCanonicalPackInStateOrder() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let sources = try prepareMixedSources(
            in: fixture.rootURL
        )
        try fixture.builder.build(
            mixedRequest(sources: sources),
            at: fixture.destinationURL
        )

        try assertCanonicalBuild(
            fixture: fixture,
            sources: sources
        )
    }

    func testBuildRejectsDuplicateStatesBeforeCreatingDestination() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let request = CharacterPackBuildRequest(
            name: "Duplicate",
            defaultState: .run,
            clips: [
                CharacterPackBuildClip(
                    state: .run,
                    kind: .singleImage,
                    sourceURL: fixture.rootURL.appendingPathComponent("a.png")
                ),
                CharacterPackBuildClip(
                    state: .run,
                    kind: .gif,
                    sourceURL: fixture.rootURL.appendingPathComponent("b.gif")
                )
            ]
        )

        XCTAssertThrowsError(
            try fixture.builder.build(
                request,
                at: fixture.destinationURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .duplicateState(.run)
            )
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: fixture.destinationURL.path
            )
        )
    }

    func testBuildRejectsMissingDefaultState() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let request = CharacterPackBuildRequest(
            name: "Missing Default",
            defaultState: .run,
            clips: [
                CharacterPackBuildClip(
                    state: .idle,
                    kind: .singleImage,
                    sourceURL: fixture.rootURL.appendingPathComponent("idle.png")
                )
            ]
        )

        XCTAssertThrowsError(
            try fixture.builder.build(
                request,
                at: fixture.destinationURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .defaultStateMissing(.run)
            )
        }
    }

    func testBuildRejectsSymlinkClipAndCleansStagingDirectory() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let realSource = fixture.rootURL
            .appendingPathComponent("real.png")
        let linkedSource = fixture.rootURL
            .appendingPathComponent("linked.png")
        try writeTestPNG(to: realSource)
        try FileManager.default.createSymbolicLink(
            at: linkedSource,
            withDestinationURL: realSource
        )

        XCTAssertThrowsError(
            try fixture.builder.build(
                validSingleClipRequest(
                    sourceURL: linkedSource
                ),
                at: fixture.destinationURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .symbolicLinkNotAllowed(linkedSource)
            )
        }

        let remainingNames = try FileManager.default
            .contentsOfDirectory(atPath: fixture.rootURL.path)
        XCTAssertFalse(
            remainingNames.contains {
                $0.hasPrefix(".schneerunner-build-")
            }
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: fixture.destinationURL.path
            )
        )
    }

    func testBuildDoesNotOverwriteExistingDestination() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.destinationURL,
            withIntermediateDirectories: false
        )

        XCTAssertThrowsError(
            try fixture.builder.build(
                validSingleClipRequest(
                    sourceURL: fixture.rootURL
                        .appendingPathComponent("source.png")
                ),
                at: fixture.destinationURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackBuilderError,
                .destinationExists(fixture.destinationURL)
            )
        }
    }

    func testBuildRequiresSchneeRunnerExtension() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let destinationURL = fixture.rootURL
            .appendingPathComponent("Built.zip")

        XCTAssertThrowsError(
            try fixture.builder.build(
                validSingleClipRequest(
                    sourceURL: fixture.rootURL
                        .appendingPathComponent("source.png")
                ),
                at: destinationURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackBuilderError,
                .invalidDestinationExtension("zip")
            )
        }
    }

    private func prepareMixedSources(
        in rootURL: URL
    ) throws -> BuilderSources {
        let idleGIF = rootURL.appendingPathComponent("idle.gif")
        let walkPNG = rootURL.appendingPathComponent("walk.png")
        let runDirectory = rootURL
            .appendingPathComponent("run", isDirectory: true)

        try writeTestGIF(to: idleGIF)
        try writeTestPNG(to: walkPNG)
        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )
        try writeTestPNG(
            to: runDirectory.appendingPathComponent("frame10.png")
        )
        try writeTestPNG(
            to: runDirectory.appendingPathComponent("frame2.png")
        )

        return BuilderSources(
            idleGIF: idleGIF,
            walkPNG: walkPNG,
            runDirectory: runDirectory
        )
    }

    private func mixedRequest(
        sources: BuilderSources
    ) -> CharacterPackBuildRequest {
        CharacterPackBuildRequest(
            name: "Built Runner",
            defaultState: .run,
            clips: [
                CharacterPackBuildClip(
                    state: .run,
                    kind: .pngSequence,
                    sourceURL: sources.runDirectory
                ),
                CharacterPackBuildClip(
                    state: .idle,
                    kind: .gif,
                    sourceURL: sources.idleGIF
                ),
                CharacterPackBuildClip(
                    state: .walk,
                    kind: .singleImage,
                    sourceURL: sources.walkPNG
                )
            ]
        )
    }

    private func assertCanonicalBuild(
        fixture: BuilderFixture,
        sources: BuilderSources
    ) throws {
        let loader = CharacterPackLoader()
        let manifest = try loader.validatedManifest(
            from: fixture.destinationURL
        )
        XCTAssertEqual(
            manifest.clips.map(\.state),
            [.idle, .walk, .run]
        )
        XCTAssertEqual(
            manifest.clips.map(\.path),
            [
                "clips/idle/source.gif",
                "clips/walk/source.png",
                "clips/run/frames"
            ]
        )

        let library = try loader.load(
            from: fixture.destinationURL
        )
        XCTAssertEqual(
            library.availableStates,
            [.idle, .walk, .run]
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: sources.idleGIF.path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: sources.walkPNG.path
            )
        )
    }

    private func validSingleClipRequest(
        sourceURL: URL
    ) -> CharacterPackBuildRequest {
        CharacterPackBuildRequest(
            name: "Single",
            defaultState: .run,
            clips: [
                CharacterPackBuildClip(
                    state: .run,
                    kind: .singleImage,
                    sourceURL: sourceURL
                )
            ]
        )
    }

    private func makeFixture() throws -> BuilderFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        return BuilderFixture(
            rootURL: rootURL,
            destinationURL: rootURL
                .appendingPathComponent("Built.schneerunner", isDirectory: true),
            builder: CharacterPackBuilder()
        )
    }
}

private struct BuilderFixture {
    let rootURL: URL
    let destinationURL: URL
    let builder: CharacterPackBuilder

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private struct BuilderSources {
    let idleGIF: URL
    let walkPNG: URL
    let runDirectory: URL
}
