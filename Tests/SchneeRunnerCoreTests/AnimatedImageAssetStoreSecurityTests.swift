@testable import SchneeRunnerCore
import XCTest

final class AnimatedImageAssetStoreSecurityTests: XCTestCase {
    func testRejectsSymlinkedAssetDirectory() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let id = UUID()
        let externalDirectory = fixture.root
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
            displayName: "apng",
            kind: .apng,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.store.sourceURL(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? AnimatedImageAssetStoreError,
                .symbolicLinkNotAllowed(linkedDirectory)
            )
        }
    }

    private func makeFixture() throws -> SecurityFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        let libraryDirectory = root.appendingPathComponent(
            "library",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )

        return SecurityFixture(
            root: root,
            libraryDirectory: libraryDirectory,
            store: AnimatedImageAssetStore(
                rootDirectory: libraryDirectory
            )
        )
    }
}

private struct SecurityFixture {
    let root: URL
    let libraryDirectory: URL
    let store: AnimatedImageAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
