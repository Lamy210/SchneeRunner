import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class GIFAnimationLoaderTests: XCTestCase {
    func testLoadsFramesAndPreservesDurations() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try writeGIF(
            durations: [0.05, 0.2],
            to: fixture.url
        )

        let animation = try GIFAnimationLoader().load(
            from: fixture.url
        )

        XCTAssertEqual(animation.frames.count, 2)
        XCTAssertEqual(
            animation.schedule.frameDurations[0],
            0.05,
            accuracy: 0.01
        )
        XCTAssertEqual(
            animation.schedule.frameDurations[1],
            0.2,
            accuracy: 0.01
        )
    }

    func testClampsVeryShortFrameDuration() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try writeGIF(
            durations: [0.005, 0.1],
            to: fixture.url
        )

        let animation = try GIFAnimationLoader().load(
            from: fixture.url
        )

        XCTAssertGreaterThanOrEqual(
            animation.schedule.frameDurations[0],
            0.02
        )
    }

    func testRejectsAggregatePixelBudgetBeforeDecode() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try writeGIF(
            durations: [0.1, 0.1],
            to: fixture.url
        )
        let loader = GIFAnimationLoader(
            policy: GIFAnimationPolicy(
                maximumTotalPixelCount: 7
            )
        )

        XCTAssertThrowsError(
            try loader.load(from: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? GIFAnimationLoaderError,
                .totalPixelCountTooLarge(
                    actual: 8,
                    maximum: 7
                )
            )
        }
    }

    func testRejectsSequenceOverConfiguredFrameLimit() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try writeGIF(
            durations: [0.1, 0.1, 0.1],
            to: fixture.url
        )
        let loader = GIFAnimationLoader(
            policy: GIFAnimationPolicy(
                maximumFrameCount: 2
            )
        )

        XCTAssertThrowsError(
            try loader.load(from: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? GIFAnimationLoaderError,
                .tooManyFrames(actual: 3, maximum: 2)
            )
        }
    }

    func testRejectsPNGContentWithGIFExtension() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try writePNG(to: fixture.url)

        XCTAssertThrowsError(
            try GIFAnimationLoader().load(from: fixture.url)
        ) { error in
            guard case let .unsupportedContentType(identifier) =
                error as? GIFAnimationLoaderError
            else {
                return XCTFail("Expected unsupported GIF content type.")
            }

            XCTAssertEqual(
                identifier,
                UTType.png.identifier
            )
        }
    }

    private func makeFixture() throws -> GIFFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return GIFFixture(
            directory: directory,
            url: directory.appendingPathComponent("animation.gif")
        )
    }

    private func writeGIF(
        durations: [Double],
        to url: URL
    ) throws {
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

    private func writePNG(to url: URL) throws {
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )
        let image = try makeImage(value: 255)
        CGImageDestinationAddImage(
            destination,
            image,
            nil
        )
        XCTAssertTrue(
            CGImageDestinationFinalize(destination)
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

private struct GIFFixture {
    let directory: URL
    let url: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}
