@testable import SchneeRunnerCore
import XCTest

final class PNGSequenceAssetStoreTests: XCTestCase {
    func testImportCopiesFramesIntoOwnedDirectory() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let frame10 = fixture.sourceDirectory
            .appendingPathComponent("frame10.png")
        let frame2 = fixture.sourceDirectory
            .appendingPathComponent("frame2.png")
        let pngData = try onePixelPNGData()
        try pngData.write(to: frame10)
        try pngData.write(to: frame2)

        let asset = try fixture.sequenceStore.importSequence(
            from: [frame10, frame2],
            createdAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(asset.kind, .pngSequence)
        XCTAssertEqual(asset.displayName, "frame2 Sequence")

        let storedURLs = try fixture.sequenceStore.sourceURLs(
            for: asset
        )
        XCTAssertEqual(
            storedURLs.map(\.lastPathComponent),
            ["0001.png", "0002.png"]
        )
        XCTAssertEqual(
            try storedURLs.map(Data.init(contentsOf:)),
            [pngData, pngData]
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: frame10.path)
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: frame2.path)
        )
    }

    func testSharedCharacterStoreCanListSequenceManifest() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let frame1 = fixture.sourceDirectory
            .appendingPathComponent("frame1.png")
        let frame2 = fixture.sourceDirectory
            .appendingPathComponent("frame2.png")
        let pngData = try onePixelPNGData()
        try pngData.write(to: frame1)
        try pngData.write(to: frame2)

        let asset = try fixture.sequenceStore.importSequence(
            from: [frame1, frame2]
        )

        XCTAssertEqual(
            try fixture.characterStore.asset(id: asset.id),
            asset
        )
    }

    func testRejectsWrongAssetKindWhenReadingSources() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let asset = StoredCharacterAsset(
            id: UUID(),
            displayName: "single",
            kind: .singleImage,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.sequenceStore.sourceURLs(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceAssetStoreError,
                .wrongAssetKind(.singleImage)
            )
        }
    }

    private func makeFixture() throws -> SequenceStoreFixture {
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

        return SequenceStoreFixture(
            temporaryRoot: temporaryRoot,
            sourceDirectory: sourceDirectory,
            sequenceStore: PNGSequenceAssetStore(
                rootDirectory: libraryDirectory
            ),
            characterStore: CharacterAssetStore(
                rootDirectory: libraryDirectory
            )
        )
    }

    private func onePixelPNGData() throws -> Data {
        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk" +
            "+A8AAQUBAScY42YAAAAASUVORK5CYII="
        return try XCTUnwrap(
            Data(base64Encoded: encoded)
        )
    }
}

private struct SequenceStoreFixture {
    let temporaryRoot: URL
    let sourceDirectory: URL
    let sequenceStore: PNGSequenceAssetStore
    let characterStore: CharacterAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}
