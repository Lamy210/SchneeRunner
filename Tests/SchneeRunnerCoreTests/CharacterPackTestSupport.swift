import CoreGraphics
import Foundation
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

func makePackFixture() throws -> PackFixture {
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

func writePackManifest(
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

func writeTestGIF(to url: URL) throws {
    let destination = try XCTUnwrap(
        CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            2,
            nil
        )
    )

    for value in [UInt8(64), UInt8(192)] {
        let image = try makeTestImage(value: value)
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

func writeTestPNG(
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
    let image = try makeTestImage(
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

func makeTestImage(
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

struct PackFixture {
    let rootURL: URL
    let packageURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
