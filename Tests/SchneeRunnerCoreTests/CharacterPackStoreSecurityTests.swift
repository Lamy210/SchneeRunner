@testable import SchneeRunnerCore
import XCTest

final class CharacterPackStoreSecurityTests: XCTestCase {
    func testRejectsSymlinkedStoredAssetDirectory() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let id = UUID()
        let externalDirectory = fixture.temporaryRoot
            .appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: true
        )

        let linkedDirectory = fixture.libraryDirectory
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: externalDirectory
        )

        let asset = StoredCharacterAsset(
            id: id,
            displayName: "pack",
            kind: .characterPack,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.store.load(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .symbolicLinkNotAllowed(linkedDirectory)
            )
        }
    }

    private func makeFixture() throws -> PackSecurityFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libraryDirectory = temporaryRoot
            .appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )

        return PackSecurityFixture(
            temporaryRoot: temporaryRoot,
            libraryDirectory: libraryDirectory,
            store: CharacterPackStore(
                rootDirectory: libraryDirectory
            )
        )
    }
}

private struct PackSecurityFixture {
    let temporaryRoot: URL
    let libraryDirectory: URL
    let store: CharacterPackStore

    func cleanup() {
        try? FileManager.default.removeItem(
            at: temporaryRoot
        )
    }
}
