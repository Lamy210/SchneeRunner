import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class CharacterPackLoaderTests: XCTestCase {
    func testLoadsStateSpecificGIFAndPNGSequenceAnimations() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        try fixture.writeGIF(
            relativePath: "animations/idle.gif",
            durations: [0.05, 0.2]
        )
        try fixture.writePNG(
            relativePath: "animations/run/frame1.png"
        )
        try fixture.writePNG(
            relativePath: "animations/run/frame2.png"
        )
        try fixture.writeManifest(
            CharacterPackManifest(
                schemaVersion: 1,
                name: "Sample Runner",
                defaultState: .run,
                animations: [
                    CharacterPackAnimationEntry(
                        state: .idle,
                        kind: .gif,
                        path: "animations/idle.gif"
                    ),
                    CharacterPackAnimationEntry(
                        state: .run,
                        kind: .pngSequence,
                        path: "animations/run"
                    )
                ]
            )
        )

        let pack = try CharacterPackLoader().load(
            from: fixture.packURL
        )
        let idle = pack.animations.resolve(
            requestedState: .idle
        )
        let sprint = pack.animations.resolve(
            requestedState: .sprint
        )

        XCTAssertEqual(pack.manifest.name, "Sample Runner")
        XCTAssertEqual(
            pack.animations.availableStates,
            [.idle, .run]
        )
        XCTAssertEqual(idle.resolvedState, .idle)
        XCTAssertFalse(idle.usedFallback)
        XCTAssertEqual(idle.animation.frames.count, 2)
        XCTAssertEqual(
            idle.animation.schedule.frameDurations[1],
            0.2,
            accuracy: 0.01
        )
        XCTAssertEqual(sprint.resolvedState, .run)
        XCTAssertTrue(sprint.usedFallback)
        XCTAssertEqual(sprint.animation.frames.count, 2)
    }

    func testRejectsDuplicateStates() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        try fixture.writeManifest(
            CharacterPackManifest(
                schemaVersion: 1,
                name: "Duplicate",
                defaultState: .run,
                animations: [
                    CharacterPackAnimationEntry(
                        state: .run,
                        kind: .gif,
                        path: "run-a.gif"
                    ),
                    CharacterPackAnimationEntry(
                        state: .run,
                        kind: .gif,
                        path: "run-b.gif"
                    )
                ]
            )
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(
                from: fixture.packURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .duplicateState(.run)
            )
        }
    }

    func testRejectsPathTraversalBeforeResourceAccess() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        try fixture.writeManifest(
            fixture.singleAnimationManifest(
                path: "../outside.gif"
            )
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(
                from: fixture.packURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .invalidRelativePath("../outside.gif")
            )
        }
    }

    func testRejectsSymlinkedIntermediateDirectory() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        let externalDirectory = fixture.rootURL
            .appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: true
        )
        try fixture.writeGIF(
            to: externalDirectory.appendingPathComponent("run.gif"),
            durations: [0.1, 0.1]
        )

        let linkedDirectory = fixture.packURL
            .appendingPathComponent("animations", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: externalDirectory
        )
        try fixture.writeManifest(
            fixture.singleAnimationManifest(
                path: "animations/run.gif"
            )
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(
                from: fixture.packURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .symbolicLinkNotAllowed(linkedDirectory)
            )
        }
    }

    func testRejectsUnsupportedSchemaVersion() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        try fixture.writeManifest(
            CharacterPackManifest(
                schemaVersion: 2,
                name: "Future",
                defaultState: .run,
                animations: [
                    CharacterPackAnimationEntry(
                        state: .run,
                        kind: .gif,
                        path: "run.gif"
                    )
                ]
            )
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(
                from: fixture.packURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .unsupportedSchema(
                    actual: 2,
                    expected: 1
                )
            )
        }
    }

    func testRejectsMissingDefaultStateAnimation() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        try fixture.writeManifest(
            CharacterPackManifest(
                schemaVersion: 1,
                name: "Missing Default",
                defaultState: .run,
                animations: [
                    CharacterPackAnimationEntry(
                        state: .idle,
                        kind: .gif,
                        path: "idle.gif"
                    )
                ]
            )
        )

        XCTAssertThrowsError(
            try CharacterPackLoader().load(
                from: fixture.packURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .defaultStateMissing(.run)
            )
        }
    }

    func testRejectsAggregateLoadedPixelBudget() throws {
        let fixture = try CharacterPackFixture()
        defer {
            fixture.cleanup()
        }

        try fixture.writeGIF(
            relativePath: "idle.gif",
            durations: [0.1, 0.1]
        )
        try fixture.writeGIF(
            relativePath: "run.gif",
            durations: [0.1, 0.1]
        )
        try fixture.writeManifest(
            CharacterPackManifest(
                schemaVersion: 1,
                name: "Budget",
                defaultState: .run,
                animations: [
                    CharacterPackAnimationEntry(
                        state: .idle,
                        kind: .gif,
                        path: "idle.gif"
                    ),
                    CharacterPackAnimationEntry(
                        state: .run,
                        kind: .gif,
                        path: "run.gif"
                    )
                ]
            )
        )

        let loader = CharacterPackLoader(
            policy: CharacterPackPolicy(
                maximumLoadedPixelCount: 15
            )
        )

        XCTAssertThrowsError(
            try loader.load(from: fixture.packURL)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackLoaderError,
                .loadedPixelCountTooLarge(
                    actual: 16,
                    maximum: 15
                )
            )
        }
    }
}

private struct CharacterPackFixture {
    let rootURL: URL
    let packURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        packURL = rootURL
            .appendingPathComponent("Sample.schneerunner", isDirectory: true)
        try FileManager.default.createDirectory(
            at: packURL,
            withIntermediateDirectories: true
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func singleAnimationManifest(
        path: String
    ) -> CharacterPackManifest {
        CharacterPackManifest(
            schemaVersion: 1,
            name: "Single",
            defaultState: .run,
            animations: [
                CharacterPackAnimationEntry(
                    state: .run,
                    kind: .gif,
                    path: path
                )
            ]
        )
    }

    func writeManifest(
        _ manifest: CharacterPackManifest
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(
            to: packURL.appendingPathComponent("manifest.json"),
            options: .atomic
        )
    }

    func writePNG(
        relativePath: String
    ) throws {
        let url = packURL.appendingPathComponent(relativePath)
        try writeImageDirectory(for: url)

        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )
        let image = try makeImage(value: 192)
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(
            CGImageDestinationFinalize(destination)
        )
    }

    func writeGIF(
        relativePath: String,
        durations: [Double]
    ) throws {
        let url = packURL.appendingPathComponent(relativePath)
        try writeGIF(
            to: url,
            durations: durations
        )
    }

    func writeGIF(
        to url: URL,
        durations: [Double]
    ) throws {
        try writeImageDirectory(for: url)

        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.gif.identifier as CFString,
                durations.count,
                nil
            )
        )

        for (index, duration) in durations.enumerated() {
            let image = try makeImage(
                value: UInt8(64 + index * 64)
            )
            let properties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: duration
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(
                destination,
                image,
                properties
            )
        }

        XCTAssertTrue(
            CGImageDestinationFinalize(destination)
        )
    }

    private func writeImageDirectory(
        for url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func makeImage(value: UInt8) throws -> CGImage {
        let bytes = Data(
            repeating: value,
            count: 2 * 2 * 4
        )
        let provider = try XCTUnwrap(
            CGDataProvider(data: bytes as CFData)
        )

        return try XCTUnwrap(
            CGImage(
                width: 2,
                height: 2,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 2 * 4,
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
