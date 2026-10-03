@testable import SchneeRunnerApp
import XCTest

@MainActor
final class StatusMenuControllerTests: XCTestCase {
    func testMenuOpenRequestsRecentCharactersRefresh() {
        let controller = StatusMenuController()
        var refreshCount = 0

        controller.onRefreshRecentCharacters = {
            refreshCount += 1
        }

        controller.menuWillOpen(controller.menu)

        XCTAssertEqual(refreshCount, 1)
    }
}
