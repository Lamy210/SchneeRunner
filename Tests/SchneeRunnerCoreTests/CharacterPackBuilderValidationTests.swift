@testable import SchneeRunnerCore
import XCTest

final class CharacterPackBuilderValidationTests: XCTestCase {
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
                singleClipRequest(
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
                singleClipRequest(
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
                singleClipRequest(
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

    private func singleClipRequest(
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

    private func makeFixture() throws -> BuilderValidationFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )

        return BuilderValidationFixture(
            rootURL: rootURL,
            destinationURL: rootURL
                .appendingPathComponent("Built.schneerunner", isDirectory: true),
            builder: CharacterPackBuilder()
        )
    }
}

private struct BuilderValidationFixture {
    let rootURL: URL
    let destinationURL: URL
    let builder: CharacterPackBuilder

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
