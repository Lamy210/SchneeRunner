import Foundation
@testable import VisualDiffCore
import XCTest

final class ImageDigestTests: XCTestCase {
    func testFileDigestMatchesDataDigestAcrossSmallChunks() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let data = Data("streamed-image-digest".utf8)
        let url = root.appendingPathComponent("image.bin")
        try data.write(to: url)

        XCTAssertEqual(
            try ImageDigest.sha256(
                fileAt: url,
                chunkSize: 3
            ),
            ImageDigest.sha256(data)
        )
    }
}
