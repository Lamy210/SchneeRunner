@testable import SchneeRunnerCore
import XCTest

final class CharacterPackStoreSecurityTests: XCTestCase {
    func testRejectsSymlinkedAssetDirectory() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let id = UUID()
        let externalDirectory = fixture.rootURL
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
            try fixture.store.library(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .symbolicLinkNotAllowed(linkedDirectory)
            )
        }
    }

    private func makeFixture() throws -> CharacterPackSecurityFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libraryDirectory = rootURL
            .appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )

        return CharacterPackSecurityFixture(
            rootURL: rootURL,
            libraryDirectory: libraryDirectory,
            store: CharacterPackStore(
                rootDirectory: libraryDirectory
            )
        )
    }
}

private struct CharacterPackSecurityFixture {
    let rootURL: URL
    let libraryDirectory: URL
    let store: CharacterPackStore

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
