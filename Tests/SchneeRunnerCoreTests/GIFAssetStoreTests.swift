import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class GIFAssetStoreTests: XCTestCase {
    func testImportCopiesGIFAndSupportsManifestRoundTrip() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try writeGIF(to: fixture.sourceURL)
        let originalData = try Data(contentsOf: fixture.sourceURL)

        let asset = try fixture.gifStore.importGIF(
            from: fixture.sourceURL,
            createdAt: Date(timeIntervalSince1970: 100.75)
        )

        XCTAssertEqual(asset.kind, .gif)
        XCTAssertEqual(asset.displayName, "runner")
        XCTAssertEqual(
            asset.createdAt,
            Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(
            try fixture.characterStore.asset(id: asset.id),
            asset
        )

        let copiedURL = try fixture.gifStore.sourceURL(
            for: asset
        )
        XCTAssertEqual(copiedURL.lastPathComponent, "source.gif")
        XCTAssertEqual(
            try Data(contentsOf: copiedURL),
            originalData
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.sourceURL.path
            )
        )
    }

    func testRejectsWrongAssetKindWhenResolvingSource() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let asset = StoredCharacterAsset(
            id: UUID(),
            displayName: "png",
            kind: .singleImage,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.gifStore.sourceURL(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? GIFAssetStoreError,
                .wrongAssetKind(.singleImage)
            )
        }
    }

    private func makeFixture() throws -> GIFStoreFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = temporaryRoot
            .appendingPathComponent("source", isDirectory: true)
        let libraryDirectory = temporaryRoot
            .appendingPathComponent("library", isDirectory: true)

        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )

        return GIFStoreFixture(
            temporaryRoot: temporaryRoot,
            sourceURL: sourceDirectory
                .appendingPathComponent("runner.gif"),
            gifStore: GIFAssetStore(
                rootDirectory: libraryDirectory
            ),
            characterStore: CharacterAssetStore(
                rootDirectory: libraryDirectory
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
            let properties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: 0.1
                ]
            ] as CFDictionary
            let image = try makeImage(value: value)
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

private struct GIFStoreFixture {
    let temporaryRoot: URL
    let sourceURL: URL
    let gifStore: GIFAssetStore
    let characterStore: CharacterAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}
