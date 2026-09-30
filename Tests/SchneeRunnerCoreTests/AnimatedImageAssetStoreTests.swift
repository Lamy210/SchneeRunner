@testable import SchneeRunnerCore
import XCTest

final class AnimatedImageAssetStoreTests: XCTestCase {
    func testImportsAPNGAndRoundTripsManifest() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try fixture.write(
            base64: Self.apngBase64,
            to: fixture.apngURL
        )

        let asset = try fixture.store.importAnimation(
            from: fixture.apngURL,
            format: .apng,
            createdAt: Date(timeIntervalSince1970: 100.75)
        )

        XCTAssertEqual(asset.kind, .apng)
        XCTAssertEqual(
            asset.createdAt,
            Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(
            try fixture.characterStore.asset(id: asset.id),
            asset
        )

        let copiedURL = try fixture.store.sourceURL(for: asset)
        XCTAssertEqual(
            copiedURL.lastPathComponent,
            "source.png"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fixture.apngURL.path
            )
        )
    }

    func testImportsWebPAndRoundTripsManifest() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try fixture.write(
            base64: Self.webPBase64,
            to: fixture.webPURL
        )

        let asset = try fixture.store.importAnimation(
            from: fixture.webPURL,
            format: .webP
        )

        XCTAssertEqual(asset.kind, .webP)
        XCTAssertEqual(
            try fixture.characterStore.asset(id: asset.id),
            asset
        )

        let copiedURL = try fixture.store.sourceURL(for: asset)
        XCTAssertEqual(
            copiedURL.lastPathComponent,
            "source.webp"
        )
    }

    func testRejectsWrongAssetKindWhenResolvingSource() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = StoredCharacterAsset(
            id: UUID(),
            displayName: "gif",
            kind: .gif,
            createdAt: Date()
        )

        XCTAssertThrowsError(
            try fixture.store.sourceURL(for: asset)
        ) { error in
            XCTAssertEqual(
                error as? AnimatedImageAssetStoreError,
                .wrongAssetKind(.gif)
            )
        }
    }

    private func makeFixture() throws -> AnimatedAssetFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        let sourceDirectory = root.appendingPathComponent(
            "source",
            isDirectory: true
        )
        let libraryDirectory = root.appendingPathComponent(
            "library",
            isDirectory: true
        )

        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )

        return AnimatedAssetFixture(
            root: root,
            apngURL: sourceDirectory.appendingPathComponent(
                "runner.apng"
            ),
            webPURL: sourceDirectory.appendingPathComponent(
                "runner.webp"
            ),
            store: AnimatedImageAssetStore(
                rootDirectory: libraryDirectory
            ),
            characterStore: CharacterAssetStore(
                rootDirectory: libraryDirectory
            )
        )
    }

    private static let apngBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAACGFjVEwAAAACAAAA" +
        "APONk3AAAAAaZmNUTAAAAAAAAAACAAAAAgAAAAAAAAAAAAEAFAAA/uxSegAAABRJ" +
        "REFUeJxj/M/A8J+BgYGBiQEKAB8XAgJPlM6+AAAAGmZjVEwAAAABAAAAAgAAAAIA" +
        "AAAAAAAAAAABAAUAAHh7cekAAAAYZmRBVAAAAAJ4nGNk+M/wn4GBgYGJAQoAHhgC" +
        "AjJqffAAAAAASUVORK5CYII="

    private static let webPBase64 =
        "UklGRoQAAABXRUJQVlA4WAoAAAACAAAAAQAAAQAAQU5JTQYAAAAAAAAAAABBTk1G" +
        "KAAAAAAAAAAAAAEAAAEAADIAAAJWUDhMDwAAAC8BQAAABxD9j/4HIqL/AQBBTk1G" +
        "KAAAAAAAAAAAAAEAAAEAAMgAAABWUDhMDwAAAC8BQAAAB9D/iP4HIqL/AQA="
}

private struct AnimatedAssetFixture {
    let root: URL
    let apngURL: URL
    let webPURL: URL
    let store: AnimatedImageAssetStore
    let characterStore: CharacterAssetStore

    func write(
        base64: String,
        to url: URL
    ) throws {
        let data = try XCTUnwrap(
            Data(base64Encoded: base64)
        )
        try data.write(to: url)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
