@testable import SchneeRunnerCore
import XCTest

final class CharacterAssetStoreSecurityTests: XCTestCase {
    func testRejectsSymbolicLinkSource() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let realSource = fixture.temporaryRoot
            .appendingPathComponent("real.png")
        let symbolicSource = fixture.temporaryRoot
            .appendingPathComponent("linked.png")
        try Data([1, 2, 3]).write(to: realSource)
        try FileManager.default.createSymbolicLink(
            at: symbolicSource,
            withDestinationURL: realSource
        )

        XCTAssertThrowsError(
            try fixture.store.importAsset(
                from: symbolicSource,
                kind: .singleImage
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterAssetStoreError,
                .symbolicLinkNotAllowed(symbolicSource)
            )
        }
    }

    func testRejectsManifestWhoseIDDoesNotMatchDirectory() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let directoryID = UUID()
        let manifestID = UUID()
        let directory = fixture.store.rootDirectory
            .appendingPathComponent(directoryID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let asset = StoredCharacterAsset(
            id: manifestID,
            displayName: "tampered",
            kind: .singleImage,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(asset).write(
            to: directory.appendingPathComponent("manifest.json")
        )

        XCTAssertThrowsError(
            try fixture.store.asset(id: directoryID)
        ) { error in
            XCTAssertEqual(
                error as? CharacterAssetStoreError,
                .manifestIdentityMismatch(
                    expected: directoryID,
                    actual: manifestID
                )
            )
        }
    }

    func testListSkipsSymlinkedAssetDirectories() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let externalDirectory = fixture.temporaryRoot
            .appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fixture.store.rootDirectory,
            withIntermediateDirectories: true
        )

        let linkedDirectory = fixture.store.rootDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: externalDirectory
        )

        XCTAssertTrue(try fixture.store.listAssets().isEmpty)
    }

    private func makeFixture() throws -> SecurityFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libraryDirectory = temporaryRoot
            .appendingPathComponent("library", isDirectory: true)

        try FileManager.default.createDirectory(
            at: temporaryRoot,
            withIntermediateDirectories: true
        )

        return SecurityFixture(
            temporaryRoot: temporaryRoot,
            store: CharacterAssetStore(rootDirectory: libraryDirectory)
        )
    }
}

private struct SecurityFixture {
    let temporaryRoot: URL
    let store: CharacterAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}
