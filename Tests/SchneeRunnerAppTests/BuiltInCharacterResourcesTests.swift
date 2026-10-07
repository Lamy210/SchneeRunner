import Foundation
@testable import SchneeRunnerApp
import XCTest

final class BuiltInCharacterResourcesTests: XCTestCase {
    func testYukihanaLamyWalkCycleUsesStableFrameOrder() {
        let root = URL(fileURLWithPath: "/Applications/SchneeRunner.app/Contents/Resources", isDirectory: true)

        let urls = BuiltInCharacterResources.yukihanaLamyWalkCycle(resourceRoot: root)

        XCTAssertEqual(
            urls.map(\.lastPathComponent),
            ["walk_1.png", "walk_2.png", "walk_3.png", "walk_4.png"]
        )
        XCTAssertTrue(urls.allSatisfy { url in
            url.path.contains("BuiltInCharacters/YukihanaLamy/")
        })
    }
}
