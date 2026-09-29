import Foundation
@testable import SchneeRunnerCore
import XCTest

final class CharacterPackLoaderValidationTests: XCTestCase {
    func testRejectsWrongPackageExtension() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let wrongURL = fixture.rootURL
            .appendingPathComponent("Wrong.pack", isDirectory: true)
        try FileManager.default.createDirectory(
            at: wrongURL,
            withIntermediateDirectories: true
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().validatedManifest(
                from: wrongURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .invalidPackageExtension("pack")
            )
        }
    }

    func testRejectsSymlinkedPackageRoot() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let externalPackage = fixture.rootURL
            .appendingPathComponent("External.schneerunner", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalPackage,
            withIntermediateDirectories: true
        )

        let linkedPackage = fixture.rootURL
            .appendingPathComponent("Linked.schneerunner", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedPackage,
            withDestinationURL: externalPackage
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().validatedManifest(
                from: linkedPackage
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .symbolicLinkNotAllowed(linkedPackage)
            )
        }
    }

    func testRejectsUnsafePathForms() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let unsafePaths = [
            "/tmp/run.gif",
            "./run.gif",
            "clips\\run.gif",
            ""
        ]

        for path in unsafePaths {
            try writePackManifest(
                CharacterPackManifest(
                    name: "Unsafe Path",
                    defaultState: .run,
                    clips: [
                        CharacterPackClip(
                            state: .run,
                            kind: .gif,
                            path: path
                        )
                    ]
                ),
                to: fixture.packageURL
            )

            XCTAssertThrowsError(
                try CharacterPackLoader().validatedManifest(
                    from: fixture.packageURL
                )
            ) { error in
                XCTAssertEqual(
                    error as? CharacterPackLoaderError,
                    .unsafeRelativePath(path)
                )
            }
        }
    }

    func testRejectsOversizedManifest() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let manifestURL = fixture.packageURL.appendingPathComponent(
            CharacterPackLoader.manifestFileName
        )
        try Data(repeating: 0x41, count: 32).write(
            to: manifestURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader(
                maximumManifestBytes: 16
            ).validatedManifest(
                from: fixture.packageURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .manifestTooLarge(
                    actual: 32,
                    maximum: 16
                )
            )
        }
    }

    func testRejectsParentTraversalPath() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        try writePackManifest(
            CharacterPackManifest(
                name: "Traversal",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .run,
                        kind: .gif,
                        path: "../outside.gif"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().validatedManifest(
                from: fixture.packageURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .unsafeRelativePath("../outside.gif")
            )
        }
    }

    func testRejectsIntermediateSymlink() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let externalDirectory = fixture.rootURL
            .appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: true
        )
        let externalGIF = externalDirectory
            .appendingPathComponent("run.gif")
        try writeTestGIF(to: externalGIF)

        let linkedDirectory = fixture.packageURL
            .appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: externalDirectory
        )

        try writePackManifest(
            CharacterPackManifest(
                name: "Symlink",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .run,
                        kind: .gif,
                        path: "linked/run.gif"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().validatedManifest(
                from: fixture.packageURL
            )
        ) { error in
            guard case let .symbolicLinkNotAllowed(actualURL) =
                error as? CharacterPackLoaderError
            else {
                return XCTFail("Expected symlink rejection.")
            }

            XCTAssertEqual(
                actualURL.standardizedFileURL.path,
                linkedDirectory.standardizedFileURL.path
            )
        }
    }

    func testRejectsDuplicateState() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        try writePackManifest(
            CharacterPackManifest(
                name: "Duplicate",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .run,
                        kind: .gif,
                        path: "first.gif"
                    ),
                    CharacterPackClip(
                        state: .run,
                        kind: .gif,
                        path: "second.gif"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().validatedManifest(
                from: fixture.packageURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .duplicateState(.run)
            )
        }
    }

    func testRejectsPackOverTotalFrameLimit() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let imageURL = fixture.packageURL
            .appendingPathComponent("run.png")
        try writeTestPNG(to: imageURL)
        try writePackManifest(
            CharacterPackManifest(
                name: "Frame Budget",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .run,
                        kind: .singleImage,
                        path: "run.png"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader(
                maximumTotalFrameCount: 7
            ).load(
                from: fixture.packageURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .tooManyDecodedFrames(
                    actual: 8,
                    maximum: 7
                )
            )
        }
    }

    func testRejectsPackOverDecodedPixelBudget() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        let gifURL = fixture.packageURL
            .appendingPathComponent("run.gif")
        try writeTestGIF(to: gifURL)
        try writePackManifest(
            CharacterPackManifest(
                name: "Pixel Budget",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .run,
                        kind: .gif,
                        path: "run.gif"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader(
                maximumTotalDecodedPixels: 7
            ).load(
                from: fixture.packageURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .decodedPixelBudgetExceeded(
                    actual: 8,
                    maximum: 7
                )
            )
        }
    }

    func testRejectsMissingDefaultStateClip() throws {
        let fixture = try makePackFixture()
        defer { fixture.cleanup() }

        try writePackManifest(
            CharacterPackManifest(
                name: "Missing Default",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .idle,
                        kind: .gif,
                        path: "idle.gif"
                    )
                ]
            ),
            to: fixture.packageURL
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().validatedManifest(
                from: fixture.packageURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .defaultStateMissing(.run)
            )
        }
    }
}
