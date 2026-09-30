@testable import SchneeRunnerCore
import XCTest

final class CharacterPackExportTests: XCTestCase {
    func testExportRecanonicalizesAndDropsUnreferencedFiles() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try preparePack(fixture)
        let asset = try fixture.packStore.importPack(
            from: fixture.sourcePackageURL
        )
        let ownedPackage = fixture.libraryDirectory
            .appendingPathComponent(asset.id.uuidString, isDirectory: true)
            .appendingPathComponent(
                CharacterPackStore.packageDirectoryName,
                isDirectory: true
            )
        try Data("tampered".utf8).write(
            to: ownedPackage.appendingPathComponent("tampered.txt")
        )

        let exportURL = fixture.rootURL
            .appendingPathComponent("Exported.schneerunner", isDirectory: true)
        try fixture.packStore.exportPack(
            for: asset,
            to: exportURL
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: exportURL
                    .appendingPathComponent("tampered.txt")
                    .path
            )
        )

        let loader = CharacterPackLoader()
        let manifest = try loader.validatedManifest(
            from: exportURL
        )
        XCTAssertEqual(manifest.name, "Portable Runner")
        XCTAssertEqual(manifest.defaultState, .run)
        XCTAssertEqual(
            manifest.clips.map(\.path),
            [
                "clips/idle/source.gif",
                "clips/walk/source.png",
                "clips/run/frames"
            ]
        )

        let library = try loader.load(from: exportURL)
        XCTAssertEqual(
            library.availableStates,
            [.idle, .walk, .run]
        )
    }

    func testExportRejectsNonCharacterPackAsset() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        let asset = StoredCharacterAsset(
            id: UUID(),
            displayName: "Not a Pack",
            kind: .singleImage,
            createdAt: Date()
        )
        let exportURL = fixture.rootURL
            .appendingPathComponent("Exported.schneerunner", isDirectory: true)

        XCTAssertThrowsError(
            try fixture.packStore.exportPack(
                for: asset,
                to: exportURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .wrongAssetKind(.singleImage)
            )
        }
    }

    func testExportRequiresCharacterPackExtension() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try preparePack(fixture)
        let asset = try fixture.packStore.importPack(
            from: fixture.sourcePackageURL
        )
        let exportURL = fixture.rootURL
            .appendingPathComponent("Exported.zip")

        XCTAssertThrowsError(
            try fixture.packStore.exportPack(
                for: asset,
                to: exportURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .invalidExportExtension("zip")
            )
        }
    }

    func testExportDoesNotOverwriteExistingDestination() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        try preparePack(fixture)
        let asset = try fixture.packStore.importPack(
            from: fixture.sourcePackageURL
        )
        let exportURL = fixture.rootURL
            .appendingPathComponent("Exported.schneerunner", isDirectory: true)
        try FileManager.default.createDirectory(
            at: exportURL,
            withIntermediateDirectories: false
        )

        XCTAssertThrowsError(
            try fixture.packStore.exportPack(
                for: asset,
                to: exportURL
            )
        ) { error in
            XCTAssertEqual(
                error as? CharacterPackStoreError,
                .exportDestinationExists(exportURL)
            )
        }
    }

    private func makeFixture() throws -> ExportFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourcePackageURL = rootURL
            .appendingPathComponent("Source.schneerunner", isDirectory: true)
        let libraryDirectory = rootURL
            .appendingPathComponent("library", isDirectory: true)

        try FileManager.default.createDirectory(
            at: sourcePackageURL,
            withIntermediateDirectories: true
        )

        return ExportFixture(
            rootURL: rootURL,
            sourcePackageURL: sourcePackageURL,
            libraryDirectory: libraryDirectory,
            packStore: CharacterPackStore(
                rootDirectory: libraryDirectory
            )
        )
    }

    private func preparePack(_ fixture: ExportFixture) throws {
        let idleGIF = fixture.sourcePackageURL
            .appendingPathComponent("idle.gif")
        try writeTestGIF(to: idleGIF)

        let walkPNG = fixture.sourcePackageURL
            .appendingPathComponent("walk.png")
        try writeTestPNG(to: walkPNG)

        let runDirectory = fixture.sourcePackageURL
            .appendingPathComponent("run", isDirectory: true)
        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )
        try writeTestPNG(
            to: runDirectory.appendingPathComponent("frame10.png")
        )
        try writeTestPNG(
            to: runDirectory.appendingPathComponent("frame2.png")
        )

        try writePackManifest(
            CharacterPackManifest(
                name: "Portable Runner",
                defaultState: .run,
                clips: [
                    CharacterPackClip(
                        state: .idle,
                        kind: .gif,
                        path: "idle.gif"
                    ),
                    CharacterPackClip(
                        state: .walk,
                        kind: .singleImage,
                        path: "walk.png"
                    ),
                    CharacterPackClip(
                        state: .run,
                        kind: .pngSequence,
                        path: "run"
                    )
                ]
            ),
            to: fixture.sourcePackageURL
        )
    }
}

private struct ExportFixture {
    let rootURL: URL
    let sourcePackageURL: URL
    let libraryDirectory: URL
    let packStore: CharacterPackStore

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
