@testable import SchneeRunnerCore
import XCTest

final class MemoryPressureStatePolicyTests: XCTestCase {
    func testMapsPressureLevelsToEscalatingStates() {
        let policy = MemoryPressureStatePolicy()

        XCTAssertNil(policy.state(for: .normal))
        XCTAssertEqual(policy.state(for: .warning), .dash)
        XCTAssertEqual(policy.state(for: .critical), .sprint)
    }
}
