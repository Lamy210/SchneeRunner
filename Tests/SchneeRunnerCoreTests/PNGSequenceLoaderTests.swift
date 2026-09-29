import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class PNGSequenceLoaderTests: XCTestCase {
    func testOrdersFrameNamesNumerically() {
        let loader = PNGSequenceLoader()
        let urls = [
            URL(fileURLWithPath: "/tmp/frame10.png"),
            URL(fileURLWithPath: "/tmp/frame2.png"),
            URL(fileURLWithPath: "/tmp/frame1.png")
        ]

        XCTAssertEqual(
            loader.orderedSourceURLs(urls).map(\.lastPathComponent),
            ["frame1.png", "frame2.png", "frame10.png"]
        )
    }

    func testRejectsSingleFrameSequence() {
        let loader = PNGSequenceLoader()

        XCTAssertThrowsError(
            try loader.validatedOrderedURLs([
                URL(fileURLWithPath: "/tmp/frame1.png")
            ])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .insufficientFrames(actual: 1)
            )
        }
    }

    func testRejectsSequenceOverConfiguredLimit() {
        let loader = PNGSequenceLoader(maximumFrameCount: 2)

        XCTAssertThrowsError(
            try loader.validatedOrderedURLs([
                URL(fileURLWithPath: "/tmp/frame1.png"),
                URL(fileURLWithPath: "/tmp/frame2.png"),
                URL(fileURLWithPath: "/tmp/frame3.png")
            ])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .tooManyFrames(actual: 3, maximum: 2)
            )
        }
    }

    func testRejectsInconsistentFrameDimensions() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let first = fixture.directory.appendingPathComponent("frame1.png")
        let second = fixture.directory.appendingPathComponent("frame2.png")
        try writePNG(width: 2, height: 2, to: first)
        try writePNG(width: 3, height: 2, to: second)

        XCTAssertThrowsError(
            try PNGSequenceLoader().validatedOrderedURLs([
                first,
                second
            ])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .inconsistentDimensions(
                    expectedWidth: 2,
                    expectedHeight: 2,
                    actualWidth: 3,
                    actualHeight: 2,
                    fileName: "frame2.png"
                )
            )
        }
    }

    func testRejectsAggregateFileByteBudget() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let first = fixture.directory.appendingPathComponent("frame1.png")
        let second = fixture.directory.appendingPathComponent("frame2.png")
        try writePNG(width: 2, height: 2, to: first)
        try writePNG(width: 2, height: 2, to: second)

        let combinedSize = try [first, second].reduce(into: 0) { total, url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            total += try XCTUnwrap(values.fileSize)
        }
        let loader = PNGSequenceLoader(
            maximumTotalFileBytes: combinedSize - 1
        )

        XCTAssertThrowsError(
            try loader.validatedOrderedURLs([first, second])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .totalFileSizeTooLarge(
                    actual: combinedSize,
                    maximum: combinedSize - 1
                )
            )
        }
    }

    func testRejectsAggregatePixelBudget() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let first = fixture.directory.appendingPathComponent("frame1.png")
        let second = fixture.directory.appendingPathComponent("frame2.png")
        try writePNG(width: 2, height: 2, to: first)
        try writePNG(width: 2, height: 2, to: second)

        let loader = PNGSequenceLoader(
            maximumTotalPixelCount: 7
        )

        XCTAssertThrowsError(
            try loader.validatedOrderedURLs([first, second])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .totalPixelCountTooLarge(
                    actual: 8,
                    maximum: 7
                )
            )
        }
    }

    private func makeFixture() throws -> PNGSequenceFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return PNGSequenceFixture(directory: directory)
    }

    private func writePNG(
        width: Int,
        height: Int,
        to url: URL
    ) throws {
        let bytes = Data(
            repeating: 255,
            count: width * height * 4
        )
        let provider = try XCTUnwrap(
            CGDataProvider(data: bytes as CFData)
        )
        let image = try XCTUnwrap(
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
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )

        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}

private struct PNGSequenceFixture {
    let directory: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}
