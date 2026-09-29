@testable import SchneeRunnerCore
import XCTest

final class CharacterPackLoaderTests: XCTestCase {
    func testLoadsStateSpecificAnimationsWithDefaultFallback() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let packURL = try fixture.makePack(
            name: "Snow Runner",
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .idle,
                    kind: .singleImage,
                    path: "idle.png"
                ),
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "run.png"
                )
            ]
        )

        let loaded = try CharacterPackLoader().load(
            from: packURL
        )

        XCTAssertEqual(loaded.displayName, "Snow Runner")
        XCTAssertEqual(
            loaded.library.availableStates,
            [.idle, .run]
        )

        let exact = loaded.library.resolve(
            requestedState: .idle
        )
        XCTAssertEqual(exact.resolvedState, .idle)
        XCTAssertFalse(exact.usedFallback)

        let fallback = loaded.library.resolve(
            requestedState: .walk
        )
        XCTAssertEqual(fallback.resolvedState, .run)
        XCTAssertTrue(fallback.usedFallback)
    }

    func testRejectsPackDecodedPixelBudget() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let packURL = try fixture.makePack(
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "run.png"
                )
            ]
        )
        let loader = CharacterPackLoader(
            policy: CharacterPackPolicy(
                maximumTotalDecodedPixels: 1
            )
        )

        XCTAssertThrowsError(
            try loader.load(from: packURL)
        ) { error in
            guard case let .decodedPixelBudgetExceeded(
                actual,
                maximum
            ) = error as? CharacterPackLoaderError else {
                return XCTFail("Expected decoded pixel budget failure.")
            }

            XCTAssertGreaterThan(actual, 1)
            XCTAssertEqual(maximum, 1)
        }
    }

    func testRejectsDuplicateStateDefinitions() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let packURL = try fixture.makePack(
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "run.png"
                ),
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "idle.png"
                )
            ]
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(from: packURL)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .duplicateState(.run)
            )
        }
    }

    func testRejectsMissingDefaultStateClip() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let packURL = try fixture.makePack(
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .idle,
                    kind: .singleImage,
                    path: "idle.png"
                )
            ]
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(from: packURL)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .defaultStateMissing(.run)
            )
        }
    }

    func testRejectsPathTraversal() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let packURL = try fixture.makePack(
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "../outside.png"
                )
            ]
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(from: packURL)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .invalidRelativePath("../outside.png")
            )
        }
    }

    func testRejectsSymlinkedPackResource() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let packURL = try fixture.makePack(
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "run.png"
                )
            ]
        )
        let externalURL = fixture.rootDirectory
            .appendingPathComponent("external.png")
        try fixture.pngData().write(to: externalURL)

        let linkedURL = packURL.appendingPathComponent(
            ".hidden-link.png"
        )
        try FileManager.default.createSymbolicLink(
            at: linkedURL,
            withDestinationURL: externalURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(from: packURL)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .symbolicLinkNotAllowed(linkedURL)
            )
        }
    }

    private func makeFixture() throws -> CharacterPackFixture {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
        return CharacterPackFixture(
            rootDirectory: rootDirectory
        )
    }
}

private struct CharacterPackFixture {
    let rootDirectory: URL

    func makePack(
        name: String = "Runner",
        defaultState: CharacterState,
        clips: [CharacterPackClipManifest]
    ) throws -> URL {
        let packURL = rootDirectory.appendingPathComponent(
            "Runner.schneerunnerpack",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: packURL,
            withIntermediateDirectories: true
        )

        let png = try pngData()
        try png.write(
            to: packURL.appendingPathComponent("idle.png")
        )
        try png.write(
            to: packURL.appendingPathComponent("run.png")
        )

        let manifest = CharacterPackManifest(
            name: name,
            defaultState: defaultState,
            clips: clips
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: packURL.appendingPathComponent("manifest.json")
        )
        return packURL
    }

    func pngData() throws -> Data {
        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk" +
            "+A8AAQUBAScY42YAAAAASUVORK5CYII="
        return try XCTUnwrap(
            Data(base64Encoded: encoded)
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(
            at: rootDirectory
        )
    }
}
