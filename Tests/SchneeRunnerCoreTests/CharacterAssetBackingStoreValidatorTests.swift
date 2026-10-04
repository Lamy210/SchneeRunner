@testable import SchneeRunnerCore
import XCTest

final class CharacterAssetBackingStoreValidatorTests: XCTestCase {
    func testSingleSourceRequiresOwnedRegularFile() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = fixture.asset(kind: .singleImage)
        let assetDirectory = try fixture.makeAssetDirectory(for: asset)
        let sourceURL = assetDirectory.appendingPathComponent("source.png")
        try Data([1]).write(to: sourceURL)

        XCTAssertTrue(fixture.validator.isStructurallyAvailable(asset))

        try FileManager.default.removeItem(at: sourceURL)

        XCTAssertFalse(fixture.validator.isStructurallyAvailable(asset))
    }

    func testSingleSourceRejectsSymbolicLink() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = fixture.asset(kind: .singleImage)
        let assetDirectory = try fixture.makeAssetDirectory(for: asset)
        let targetURL = fixture.rootURL.appendingPathComponent("target.png")
        try Data([1]).write(to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: assetDirectory.appendingPathComponent("source.png"),
            withDestinationURL: targetURL
        )

        XCTAssertFalse(fixture.validator.isStructurallyAvailable(asset))
    }

    func testDedicatedSingleSourceKindsUseCanonicalFileNames() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let cases: [(CharacterAssetKind, String)] = [
            (.gif, "source.gif"),
            (.apng, "source.png"),
            (.webP, "source.webp")
        ]

        for (kind, fileName) in cases {
            let asset = fixture.asset(kind: kind)
            let assetDirectory = try fixture.makeAssetDirectory(for: asset)
            try Data([1]).write(
                to: assetDirectory.appendingPathComponent(fileName)
            )

            XCTAssertTrue(
                fixture.validator.isStructurallyAvailable(asset),
                "\(kind.rawValue) should use \(fileName)"
            )
        }
    }

    func testSequenceRequiresTwoRegularPNGFrames() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = fixture.asset(kind: .pngSequence)
        let assetDirectory = try fixture.makeAssetDirectory(for: asset)
        let framesDirectory = assetDirectory.appendingPathComponent(
            "frames",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: framesDirectory,
            withIntermediateDirectories: false
        )
        try Data([1]).write(
            to: framesDirectory.appendingPathComponent("0001.png")
        )

        XCTAssertFalse(fixture.validator.isStructurallyAvailable(asset))

        try Data([2]).write(
            to: framesDirectory.appendingPathComponent("0002.png")
        )

        XCTAssertTrue(fixture.validator.isStructurallyAvailable(asset))
    }

    func testCharacterPackRequiresPackageManifest() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = fixture.asset(kind: .characterPack)
        let assetDirectory = try fixture.makeAssetDirectory(for: asset)
        let packageDirectory = assetDirectory.appendingPathComponent(
            CharacterPackStore.packageDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: packageDirectory,
            withIntermediateDirectories: false
        )

        XCTAssertFalse(fixture.validator.isStructurallyAvailable(asset))

        let clipDirectory = packageDirectory.appendingPathComponent(
            "clips/run",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: clipDirectory,
            withIntermediateDirectories: true
        )
        try Data([1]).write(
            to: clipDirectory.appendingPathComponent("source.png")
        )
        try writeCharacterPackManifest(
            to: packageDirectory,
            clipPath: "clips/run/source.png"
        )

        XCTAssertTrue(fixture.validator.isStructurallyAvailable(asset))
    }

    func testCharacterPackRejectsMissingReferencedClip() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = fixture.asset(kind: .characterPack)
        let assetDirectory = try fixture.makeAssetDirectory(for: asset)
        let packageDirectory = assetDirectory.appendingPathComponent(
            CharacterPackStore.packageDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: packageDirectory,
            withIntermediateDirectories: false
        )
        try writeCharacterPackManifest(
            to: packageDirectory,
            clipPath: "clips/run/source.png"
        )

        XCTAssertFalse(fixture.validator.isStructurallyAvailable(asset))
    }

    private func writeCharacterPackManifest(
        to packageDirectory: URL,
        clipPath: String
    ) throws {
        let manifest = CharacterPackManifest(
            name: "Stored Pack",
            defaultState: .run,
            clips: [
                CharacterPackClip(
                    state: .run,
                    kind: .singleImage,
                    path: clipPath
                )
            ]
        )
        try JSONEncoder().encode(manifest).write(
            to: packageDirectory.appendingPathComponent(
                CharacterPackLoader.manifestFileName
            )
        )
    }

    private func makeFixture() throws -> BackingStoreFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let libraryURL = rootURL.appendingPathComponent(
            "library",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: libraryURL,
            withIntermediateDirectories: true
        )

        return BackingStoreFixture(
            rootURL: rootURL,
            libraryURL: libraryURL,
            validator: CharacterAssetBackingStoreValidator(
                rootDirectory: libraryURL
            )
        )
    }
}

private struct BackingStoreFixture {
    let rootURL: URL
    let libraryURL: URL
    let validator: CharacterAssetBackingStoreValidator

    func asset(kind: CharacterAssetKind) -> StoredCharacterAsset {
        StoredCharacterAsset(
            id: UUID(),
            displayName: kind.rawValue,
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    func makeAssetDirectory(
        for asset: StoredCharacterAsset
    ) throws -> URL {
        let directory = libraryURL.appendingPathComponent(
            asset.id.uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false
        )
        return directory
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
