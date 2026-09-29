@testable import SchneeRunnerCore
import XCTest

final class GIFAssetStoreSecurityTests: XCTestCase {
    func testRejectsSymlinkedAssetDirectory() throws {
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
            displayName: "gif",
            kind: .gif,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.store.sourceURL(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? GIFAssetStoreError,
                .symbolicLinkNotAllowed(linkedDirectory)
            )
        }
    }

    private func makeFixture() throws -> GIFSecurityFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libraryDirectory = temporaryRoot
            .appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )

        return GIFSecurityFixture(
            temporaryRoot: temporaryRoot,
            libraryDirectory: libraryDirectory,
            store: GIFAssetStore(
                rootDirectory: libraryDirectory
            )
        )
    }
}

private struct GIFSecurityFixture {
    let temporaryRoot: URL
    let libraryDirectory: URL
    let store: GIFAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}
