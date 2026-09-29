import CoreGraphics
import ImageIO
@testable import SchneeRunnerCore
import UniformTypeIdentifiers
import XCTest

final class CharacterPackStoreTests: XCTestCase {
    func testImportCanonicalizesReferencedClipsAndSkipsUnreferencedFiles() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try prepareMixedPack(fixture)
        let asset = try fixture.packStore.importPack(
            from: fixture.packageURL,
            createdAt: Date(timeIntervalSince1970: 100.75)
        )

        try assertImportedAsset(
            asset,
            fixture: fixture
        )
        try assertCanonicalPackage(
            asset,
            fixture: fixture
        )
    }

    func testRejectsPackageOverAggregateByteLimit() throws {
        let fixture = try makeFixture(
            maximumPackageBytes: 1
        )
        defer { fixture.cleanup() }

        let gifURL = fixture.packageURL
            .appendingPathComponent("run.gif")
        try writeGIF(to: gifURL)
        try writeManifest(
            CharacterPackManifest(
                name: "Too Large",
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
            try fixture.packStore.importPack(
                from: fixture.packageURL
            )
        ) { error in
            guard case let .packageTooLarge(actual, maximum) =
                error as? CharacterPackStoreError
            else {
                return XCTFail("Expected package size rejection.")
            }

            XCTAssertGreaterThan(actual, 1)
            XCTAssertEqual(maximum, 1)
        }
    }

    private func prepareMixedPack(
        _ fixture: CharacterPackStoreFixture
    ) throws {
        let idleGIF = fixture.packageURL
            .appendingPathComponent("idle.gif")
        try writeGIF(to: idleGIF)

        let runDirectory = fixture.packageURL
            .appendingPathComponent("run", isDirectory: true)
        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )
        try writePNG(
            to: runDirectory.appendingPathComponent("frame10.png")
        )
        try writePNG(
            to: runDirectory.appendingPathComponent("frame2.png")
        )
        try Data("do not copy".utf8).write(
            to: fixture.packageURL.appendingPathComponent("notes.txt")
        )

        try writeManifest(
            CharacterPackManifest(
                name: "Portable Runner",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .idle,
                        kind: .gif,
                        path: "idle.gif"
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
    }

    private func assertImportedAsset(
        _ asset: StoredCharacterAsset,
        fixture: CharacterPackStoreFixture
    ) throws {
        XCTAssertEqual(asset.kind, .characterPack)
        XCTAssertEqual(asset.displayName, "Portable Runner")
        XCTAssertEqual(
            asset.createdAt,
            Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(
            try fixture.characterStore.asset(id: asset.id),
            asset
        )

        let library = try fixture.packStore.library(
            for: asset
        )
        XCTAssertEqual(
            library.availableStates,
            [.idle, .run]
        )
        XCTAssertEqual(
            library.resolve(requestedState: .sprint).resolvedState,
            .run
        )
    }

    private func assertCanonicalPackage(
        _ asset: StoredCharacterAsset,
        fixture: CharacterPackStoreFixture
    ) throws {
        let ownedPackage = fixture.libraryDirectory
            .appendingPathComponent(asset.id.uuidString, isDirectory: true)
            .appendingPathComponent(
                CharacterPackStore.packageDirectoryName,
                isDirectory: true
            )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: ownedPackage
                    .appendingPathComponent("notes.txt")
                    .path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: ownedPackage
                    .appendingPathComponent("clips/idle/source.gif")
                    .path
            )
        )
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(
                atPath: ownedPackage
                    .appendingPathComponent("clips/run/frames")
                    .path
            ),
            ["0001.png", "0002.png"]
        )
    }

    private func makeFixture(
        maximumPackageBytes: Int = 128 * 1024 * 1024
    ) throws -> CharacterPackStoreFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let packageURL = rootURL
            .appendingPathComponent("Source.schneerunner", isDirectory: true)
        let libraryDirectory = rootURL
            .appendingPathComponent("library", isDirectory: true)

        try FileManager.default.createDirectory(
            at: packageURL,
            withIntermediateDirectories: true
        )

        return CharacterPackStoreFixture(
            rootURL: rootURL,
            packageURL: packageURL,
            libraryDirectory: libraryDirectory,
            packStore: CharacterPackStore(
                rootDirectory: libraryDirectory,
                maximumPackageBytes: maximumPackageBytes
            ),
            characterStore: CharacterAssetStore(
                rootDirectory: libraryDirectory
            )
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

    private func writePNG(to url: URL) throws {
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )
        let image = try makeImage(value: 128)
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
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

private struct CharacterPackStoreFixture {
    let rootURL: URL
    let packageURL: URL
    let libraryDirectory: URL
    let packStore: CharacterPackStore
    let characterStore: CharacterAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
