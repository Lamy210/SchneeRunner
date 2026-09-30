@testable import SchneeRunnerCore
import XCTest

final class BatteryWarningStatePolicyTests: XCTestCase {
    func testMapsWarningsToConservativeCharacterStates() {
        let policy = BatteryWarningStatePolicy()

        XCTAssertNil(policy.state(for: .none))
        XCTAssertEqual(policy.state(for: .early), .walk)
        XCTAssertEqual(policy.state(for: .final), .idle)
    }
}
