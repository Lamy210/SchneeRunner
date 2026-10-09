import Foundation
@testable import SchneeRunnerApp
import XCTest

final class BuiltInCharacterResourcesTests: XCTestCase {
    func testYukihanaLamyWalkCycleUsesStableFrameOrder() {
        let root = URL(
            fileURLWithPath: "/Applications/SchneeRunner.app/Contents/Resources",
            isDirectory: true
        )

        let urls = BuiltInCharacterResources.yukihanaLamyWalkCycle(resourceRoot: root)

        XCTAssertEqual(
            urls.map(\.lastPathComponent),
            ["walk_1.png", "walk_2.png", "walk_3.png", "walk_4.png"]
        )
        XCTAssertTrue(
            urls.allSatisfy { $0.path.contains("BuiltInCharacters/YukihanaLamy/") }
        )
    }

    func testSwiftPMModuleBundleContainsFourReadablePNGFrames() throws {
        let bundle = BuiltInCharacterResources.moduleBundle
        let urls = BuiltInCharacterResources.yukihanaLamyWalkCycle(bundle: bundle)
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        XCTAssertEqual(urls.map(\.lastPathComponent), [
            "walk_1.png", "walk_2.png", "walk_3.png", "walk_4.png",
        ])
        for url in urls {
            XCTAssertTrue(FileManager.default.isReadableFile(atPath: url.path))
            let data = try Data(contentsOf: url)
            XCTAssertEqual(data.prefix(pngSignature.count), pngSignature)
            XCTAssertGreaterThan(data.count, 8_000)
        }
    }
}
