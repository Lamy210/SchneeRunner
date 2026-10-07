import Foundation
@testable import SchneeRunnerApp
import XCTest

final class BundledDefaultCharacterTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testFrameURLsResolveInStableWalkOrder() throws {
        let characterDirectory = temporaryDirectory
            .appendingPathComponent("DefaultCharacter", isDirectory: true)
        try FileManager.default.createDirectory(
            at: characterDirectory,
            withIntermediateDirectories: true
        )

        for name in BundledDefaultCharacter.frameFileNames {
            FileManager.default.createFile(
                atPath: characterDirectory.appendingPathComponent(name).path,
                contents: Data([0x89, 0x50, 0x4E, 0x47])
            )
        }

        let urls = try BundledDefaultCharacter.frameURLs(
            resourceRoot: temporaryDirectory
        )

        XCTAssertEqual(
            urls.map(\.lastPathComponent),
            [
                "lamy-walk-01.png",
                "lamy-walk-02.png",
                "lamy-walk-03.png",
                "lamy-walk-04.png"
            ]
        )
    }

    func testMissingFrameFailsClosed() throws {
        let characterDirectory = temporaryDirectory
            .appendingPathComponent("DefaultCharacter", isDirectory: true)
        try FileManager.default.createDirectory(
            at: characterDirectory,
            withIntermediateDirectories: true
        )

        for name in BundledDefaultCharacter.frameFileNames.dropLast() {
            FileManager.default.createFile(
                atPath: characterDirectory.appendingPathComponent(name).path,
                contents: Data([0x89, 0x50, 0x4E, 0x47])
            )
        }

        XCTAssertThrowsError(
            try BundledDefaultCharacter.frameURLs(
                resourceRoot: temporaryDirectory
            )
        )
    }
}
