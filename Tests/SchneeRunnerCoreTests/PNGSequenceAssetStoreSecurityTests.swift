@testable import SchneeRunnerCore
import XCTest

final class PNGSequenceAssetStoreSecurityTests: XCTestCase {
    func testRejectsSymlinkedFramesDirectory() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let id = UUID()
        let assetDirectory = fixture.libraryDirectory
            .appendingPathComponent(id.uuidString, isDirectory: true)
        let externalDirectory = fixture.temporaryRoot
            .appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(
            at: assetDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: externalDirectory,
            withIntermediateDirectories: true
        )

        let framesDirectory = assetDirectory
            .appendingPathComponent("frames", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: framesDirectory,
            withDestinationURL: externalDirectory
        )

        let asset = StoredCharacterAsset(
            id: id,
            displayName: "sequence",
            kind: .pngSequence,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.store.sourceURLs(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceAssetStoreError,
                .symbolicLinkNotAllowed(framesDirectory)
            )
        }
    }

    private func makeFixture() throws -> SecurityFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libraryDirectory = temporaryRoot
            .appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: libraryDirectory,
            withIntermediateDirectories: true
        )

        return SecurityFixture(
            temporaryRoot: temporaryRoot,
            libraryDirectory: libraryDirectory,
            store: PNGSequenceAssetStore(
                rootDirectory: libraryDirectory
            )
        )
    }
}

private struct SecurityFixture {
    let temporaryRoot: URL
    let libraryDirectory: URL
    let store: PNGSequenceAssetStore

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }
}
