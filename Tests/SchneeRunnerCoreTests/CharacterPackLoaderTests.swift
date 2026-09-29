import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class CharacterPackLoaderTests: XCTestCase {
    func testLoadsMixedStateClipsAndResolvesFallback() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let idleURL = fixture.packageURL
            .appendingPathComponent("idle.gif")
        try writeGIF(to: idleURL)

        let walkURL = fixture.packageURL
            .appendingPathComponent("walk.png")
        try writePNG(to: walkURL)

        let runDirectory = fixture.packageURL
            .appendingPathComponent("run", isDirectory: true)
        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )
        try writePNG(
            to: runDirectory.appendingPathComponent("frame1.png")
        )
        try writePNG(
            to: runDirectory.appendingPathComponent("frame2.png")
        )

        try writeManifest(
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

        let library = try CharacterPackLoader().load(
            from: fixture.packageURL
        )

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

    func testLoadsSpriteSheetClip() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let spriteURL = fixture.packageURL
            .appendingPathComponent("run.png")
        try writePNG(
            width: 8,
            height: 4,
            to: spriteURL
        )
        try writeManifest(
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

    func testRejectsWrongPackageExtension() throws {
        let fixture = try makeFixture()
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

    func testRejectsOversizedManifest() throws {
        let fixture = try makeFixture()
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
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try writeManifest(
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
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let externalDirectory = fixture.rootURL
            .appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: true
        )
        let externalGIF = externalDirectory
            .appendingPathComponent("run.gif")
        try writeGIF(to: externalGIF)

        let linkedDirectory = fixture.packageURL
            .appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: externalDirectory
        )

        try writeManifest(
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
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .symbolicLinkNotAllowed(linkedDirectory)
            )
        }
    }

    func testRejectsDuplicateState() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try writeManifest(
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

    func testRejectsMissingDefaultStateClip() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try writeManifest(
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

    private func makeFixture() throws -> PackFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let packageURL = rootURL
            .appendingPathComponent("Test.schneerunner", isDirectory: true)
        try FileManager.default.createDirectory(
            at: packageURL,
            withIntermediateDirectories: true
        )

        return PackFixture(
            rootURL: rootURL,
            packageURL: packageURL
        )
    }

    private func writeManifest(
        _ manifest: CharacterPackManifest,
        to packageURL: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: packageURL.appendingPathComponent(
                CharacterPackLoader.manifestFileName
            )
        )
    }

    private func writeGIF(to url: URL) throws {
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.gif.identifier as CFString,
                2,
                nil
            )
        )

        for value in [UInt8(64), UInt8(192)] {
            let image = try makeImage(value: value)
            let properties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: 0.1
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(
                destination,
                image,
                properties
            )
        }

        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func writePNG(
        width: Int = 2,
        height: Int = 2,
        to url: URL
    ) throws {
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )
        let image = try makeImage(
            value: 128,
            width: width,
            height: height
        )
        CGImageDestinationAddImage(
            destination,
            image,
            nil
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func makeImage(
        value: UInt8,
        width: Int = 2,
        height: Int = 2
    ) throws -> CGImage {
        let bytes = Data(
            repeating: value,
            count: width * height * 4
        )
        let provider = try XCTUnwrap(
            CGDataProvider(data: bytes as CFData)
        )

        return try XCTUnwrap(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.last.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
    }
}

private struct PackFixture {
    let rootURL: URL
    let packageURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
