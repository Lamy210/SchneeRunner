import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class ImageAssetValidatorTests: XCTestCase {
    func testAcceptsSmallStaticPNG() throws {
        let fixture = try makeImageFixture(
            width: 4,
            height: 3,
            type: .png
        )
        defer {
            fixture.cleanup()
        }

        let result = try ImageAssetValidator().validate(
            url: fixture.url
        )

        XCTAssertEqual(result.width, 4)
        XCTAssertEqual(result.height, 3)
        XCTAssertEqual(result.frameCount, 1)
        XCTAssertGreaterThan(result.fileSize, 0)
    }

    func testRejectsFileBeforeImageDecodeWhenSizeLimitIsExceeded() throws {
        let fixture = try makeRawFixture(
            bytes: Data(repeating: 0, count: 16)
        )
        defer {
            fixture.cleanup()
        }

        let validator = ImageAssetValidator(
            policy: ImageAssetValidationPolicy(
                maximumFileBytes: 8
            )
        )

        XCTAssertThrowsError(
            try validator.validate(url: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? ImageAssetValidationError,
                .fileTooLarge(actual: 16, maximum: 8)
            )
        }
    }

    func testRejectsNonPNGContentEvenWithPNGExtension() throws {
        let fixture = try makeImageFixture(
            width: 2,
            height: 2,
            type: .jpeg
        )
        defer {
            fixture.cleanup()
        }

        XCTAssertThrowsError(
            try ImageAssetValidator().validate(url: fixture.url)
        ) { error in
            guard case let .unsupportedContentType(identifier) =
                error as? ImageAssetValidationError
            else {
                return XCTFail("Expected unsupported content type.")
            }

            XCTAssertEqual(identifier, UTType.jpeg.identifier)
        }
    }

    func testRejectsImageWhoseDimensionExceedsPolicy() throws {
        let fixture = try makeImageFixture(
            width: 4,
            height: 3,
            type: .png
        )
        defer {
            fixture.cleanup()
        }

        let validator = ImageAssetValidator(
            policy: ImageAssetValidationPolicy(
                maximumPixelDimension: 3
            )
        )

        XCTAssertThrowsError(
            try validator.validate(url: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? ImageAssetValidationError,
                .dimensionTooLarge(
                    width: 4,
                    height: 3,
                    maximum: 3
                )
            )
        }
    }

    func testRejectsImageWhosePixelCountExceedsPolicy() throws {
        let fixture = try makeImageFixture(
            width: 4,
            height: 3,
            type: .png
        )
        defer {
            fixture.cleanup()
        }

        let validator = ImageAssetValidator(
            policy: ImageAssetValidationPolicy(
                maximumPixelCount: 11
            )
        )

        XCTAssertThrowsError(
            try validator.validate(url: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? ImageAssetValidationError,
                .pixelCountTooLarge(
                    width: 4,
                    height: 3,
                    maximum: 11
                )
            )
        }
    }

    private func makeImageFixture(
        width: Int,
        height: Int,
        type: UTType
    ) throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory.appendingPathComponent("image.png")
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
                type.identifier as CFString,
                1,
                nil
            )
        )

        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        return Fixture(
            directory: directory,
            url: url
        )
    }

    private func makeRawFixture(bytes: Data) throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory.appendingPathComponent("image.png")
        try bytes.write(to: url)

        return Fixture(
            directory: directory,
            url: url
        )
    }
}

private struct Fixture {
    let directory: URL
    let url: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}
