@testable import SchneeRunnerCore
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class SpriteSheetLoaderTests: XCTestCase {
    func testLoaderPreservesImageDataRowOrder() throws {
        let url = try makeTwoRowSpriteSheet()
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let grid = try SpriteSheetGrid(columns: 1, rows: 2)
        let frames = try SpriteSheetLoader(grid: grid).loadFrames(from: url)

        XCTAssertEqual(frames.count, 2)

        let firstColor = try representativeColor(in: frames[0])
        let secondColor = try representativeColor(in: frames[1])

        XCTAssertGreaterThan(firstColor.redComponent, 0.9)
        XCTAssertLessThan(firstColor.blueComponent, 0.1)
        XCTAssertGreaterThan(secondColor.blueComponent, 0.9)
        XCTAssertLessThan(secondColor.redComponent, 0.1)
    }

    private func makeTwoRowSpriteSheet() throws -> URL {
        let width = 2
        let height = 2
        let pixels: [UInt8] = [
            255, 0, 0, 255,
            255, 0, 0, 255,
            0, 0, 255, 255,
            0, 0, 255, 255,
        ]

        let data = Data(pixels)
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        let image = try XCTUnwrap(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
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
        return url
    }

    private func representativeColor(in image: NSImage) throws -> NSColor {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        let cgImage = try XCTUnwrap(
            image.cgImage(
                forProposedRect: &proposedRect,
                context: nil,
                hints: nil
            )
        )
        let representation = NSBitmapImageRep(cgImage: cgImage)
        let color = try XCTUnwrap(representation.colorAt(x: 0, y: 0))
        return try XCTUnwrap(color.usingColorSpace(.deviceRGB))
    }
}
