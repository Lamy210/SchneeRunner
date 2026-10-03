@testable import SchneeRunnerApp
import XCTest

final class CharacterPackFileNamePolicyTests: XCTestCase {
    func testKeepsExistingCharacterPackExtension() {
        XCTAssertEqual(
            CharacterPackFileNamePolicy.fileName(
                for: "My Runner.schneerunner"
            ),
            "My Runner.schneerunner"
        )
    }

    func testAppendsCharacterPackExtensionWhenMissing() {
        XCTAssertEqual(
            CharacterPackFileNamePolicy.fileName(
                for: "My Runner"
            ),
            "My Runner.schneerunner"
        )
    }
}
