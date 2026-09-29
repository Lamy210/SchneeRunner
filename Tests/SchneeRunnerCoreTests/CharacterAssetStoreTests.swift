@testable import SchneeRunnerCore
import XCTest

final class CharacterAssetStoreTests: XCTestCase {
    func testImportCopiesSourceAndLeavesOriginalUntouched() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let originalData = try pngData()
        try originalData.write(to: fixture.sourceURL)

        let asset = try fixture.store.importAsset(
            from: fixture.sourceURL,
            kind: .singleImage,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(asset.displayName, "character")
        XCTAssertEqual(asset.kind, .singleImage)
        XCTAssertEqual(try Data(contentsOf: fixture.sourceURL), originalData)

        let copiedURL = try fixture.store.sourceURL(for: asset)
        XCTAssertEqual(try Data(contentsOf: copiedURL), originalData)
        XCTAssertEqual(copiedURL.lastPathComponent, "source.png")
        XCTAssertNotEqual(copiedURL, fixture.sourceURL)
    }

    func testListAssetsReturnsNewestFirst() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try pngData().write(to: fixture.sourceURL)

        let older = try fixture.store.importAsset(
            from: fixture.sourceURL,
            kind: .singleImage,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = try fixture.store.importAsset(
            from: fixture.sourceURL,
            kind: .spriteSheet4x2,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(
            try fixture.store.listAssets().map(\.id),
            [newer.id, older.id]
        )
    }

    func testRemoveAssetDeletesOwnedCopyOnly() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try pngData().write(to: fixture.sourceURL)
        let asset = try fixture.store.importAsset(
            from: fixture.sourceURL,
            kind: .singleImage
        )
        let copiedURL = try fixture.store.sourceURL(for: asset)

        try fixture.store.removeAsset(id: asset.id)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedURL.path))
    }

    func testRejectsUnsupportedManifestSchema() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let id = UUID()
        let directory = fixture.store.rootDirectory
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let asset = StoredCharacterAsset(
            schemaVersion: 2,
            id: id,
            displayName: "future",
            kind: .singleImage,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(asset).write(
            to: directory.appendingPathComponent("manifest.json")
        )

        XCTAssertThrowsError(
            try fixture.store.asset(id: id)
        ) { error in
            XCTAssertEqual(
                error as? CharacterAssetStoreError,
                .unsupportedSchemaVersion(2)
            )
        }
    }

    func testRejectsPNGExtensionWithUnreadableContent() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try Data([1, 2, 3]).write(to: fixture.sourceURL)

        XCTAssertThrowsError(
            try fixture.store.importAsset(
                from: fixture.sourceURL,
                kind: .singleImage
            )
        ) { error in
            XCTAssertEqual(
                error as? ImageAssetValidationError,
                .unsupportedContentType(nil)
            )
        }
    }

    func testRejectsSequenceKindInSingleSourceImporter() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        try pngData().write(to: fixture.sourceURL)

        XCTAssertThrowsError(
            try fixture.store.importAsset(
                from: fixture.sourceURL,
                kind: .pngSequence
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterAssetStoreError,
                .sequenceRequiresMultipleSources
            )
        }
    }

    func testRejectsNonPNGSource() throws {
        let fixture = try makeFixture(fileExtension: "jpg")
        defer {
            fixture.cleanup()
        }

        try Data([1]).write(to: fixture.sourceURL)

        XCTAssertThrowsError(
            try fixture.store.importAsset(
                from: fixture.sourceURL,
                kind: .singleImage
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterAssetStoreError,
                .unsupportedFileType("jpg")
            )
        }
    }

    private func pngData() throws -> Data {
        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk" +
            "+A8AAQUBAScY42YAAAAASUVORK5CYII="
        return try XCTUnwrap(
            Data(base64Encoded: encoded)
        )
    }

    private func makeFixture(
        fileExtension: String = "png"
    ) throws -> Fixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDirectory = temporaryRoot.appendingPathComponent(
            "source",
            isDirectory: true
        )
        let libraryDirectory = temporaryRoot.appendingPathComponent(
            "library",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )

        return Fixture(
            temporaryRoot: temporaryRoot,
            sourceURL: sourceDirectory
                .appendingPathComponent("character")
                .appendingPathExtension(fileExtension),
            store: CharacterAssetStore(rootDirectory: libraryDirectory)
        )
    }
}

private struct Fixture {
    let temporaryRoot: URL
    let sourceURL: URL
    let store: CharacterAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}
