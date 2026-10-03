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

    func testKeepsExistingCharacterPackExtensionCaseInsensitively() {
        XCTAssertEqual(
            CharacterPackFileNamePolicy.fileName(
                for: "My Runner.SCHNEERUNNER"
            ),
            "My Runner.SCHNEERUNNER"
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

    func testSanitizesPathSeparatorsBeforeAddingExtension() {
        XCTAssertEqual(
            CharacterPackFileNamePolicy.fileName(
                for: "Team/Runner:Night"
            ),
            "Team-Runner-Night.schneerunner"
        )
    }
}
