@testable import SchneeRunnerCore
import XCTest

final class CharacterPackStoreTests: XCTestCase {
    func testImportCopiesPackAndSupportsManifestRoundTrip() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let sourceURL = try fixture.makePack()
        let asset = try fixture.packStore.importPack(
            from: sourceURL,
            createdAt: Date(timeIntervalSince1970: 100.75)
        )

        XCTAssertEqual(asset.kind, .characterPack)
        XCTAssertEqual(asset.displayName, "Pack Runner")
        XCTAssertEqual(
            asset.createdAt,
            Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(
            try fixture.characterStore.asset(id: asset.id),
            asset
        )

        try FileManager.default.removeItem(at: sourceURL)

        let loaded = try fixture.packStore.load(
            for: asset
        )
        XCTAssertEqual(loaded.displayName, "Pack Runner")
        XCTAssertEqual(
            loaded.library.availableStates,
            [.idle, .run]
        )
    }

    func testRejectsWrongAssetKindWhenLoadingPack() throws {
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
            try fixture.packStore.load(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .wrongAssetKind(.singleImage)
            )
        }
    }

    private func makeFixture() throws -> PackStoreFixture {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceRoot = temporaryRoot.appendingPathComponent(
            "source",
            isDirectory: true
        )
        let libraryRoot = temporaryRoot.appendingPathComponent(
            "library",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sourceRoot,
            withIntermediateDirectories: true
        )

        return PackStoreFixture(
            temporaryRoot: temporaryRoot,
            sourceRoot: sourceRoot,
            packStore: CharacterPackStore(
                rootDirectory: libraryRoot
            ),
            characterStore: CharacterAssetStore(
                rootDirectory: libraryRoot
            )
        )
    }
}

private struct PackStoreFixture {
    let temporaryRoot: URL
    let sourceRoot: URL
    let packStore: CharacterPackStore
    let characterStore: CharacterAssetStore

    func makePack() throws -> URL {
        let packURL = sourceRoot.appendingPathComponent(
            "PackRunner.schneerunnerpack",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: packURL,
            withIntermediateDirectories: true
        )

        let encoded = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk" +
            "+A8AAQUBAScY42YAAAAASUVORK5CYII="
        let png = try XCTUnwrap(
            Data(base64Encoded: encoded)
        )
        try png.write(
            to: packURL.appendingPathComponent("idle.png")
        )
        try png.write(
            to: packURL.appendingPathComponent("run.png")
        )

        let manifest = CharacterPackManifest(
            name: "Pack Runner",
            defaultState: .run,
            clips: [
                CharacterPackClipManifest(
                    state: .idle,
                    kind: .singleImage,
                    path: "idle.png"
                ),
                CharacterPackClipManifest(
                    state: .run,
                    kind: .singleImage,
                    path: "run.png"
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(
            to: packURL.appendingPathComponent("manifest.json")
        )
        return packURL
    }

    func cleanup() {
        try? FileManager.default.removeItem(
            at: temporaryRoot
        )
    }
}
