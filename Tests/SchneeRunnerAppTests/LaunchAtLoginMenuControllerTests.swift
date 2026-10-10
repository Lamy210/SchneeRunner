import AppKit
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class LaunchAtLoginMenuControllerTests: XCTestCase {
    func testUnavailableRuntimeDisablesItemWithoutTouchingService() {
        let service = RecordingLaunchAtLoginService(status: .notRegistered)
        let controller = LaunchAtLoginMenuController(
            service: service,
            isAvailable: false
        )

        XCTAssertFalse(controller.item.isEnabled)
        XCTAssertEqual(controller.item.state, .off)
        XCTAssertTrue(controller.item.title.contains("Unavailable"))
        XCTAssertEqual(service.statusReadCount, 0)

        controller.toggleLaunchAtLogin()

        XCTAssertEqual(service.statusReadCount, 0)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
        XCTAssertEqual(service.openSettingsCount, 0)
    }

    func testAvailableRuntimePreservesRegistrationBehavior() {
        let service = RecordingLaunchAtLoginService(status: .notRegistered)
        let controller = LaunchAtLoginMenuController(
            service: service,
            isAvailable: true
        )

        XCTAssertTrue(controller.item.isEnabled)
        controller.toggleLaunchAtLogin()

        XCTAssertEqual(service.registerCount, 1)
    }

    func testAvailableRuntimeOpensSettingsWhenApprovalIsRequired() {
        let service = RecordingLaunchAtLoginService(status: .requiresApproval)
        let controller = LaunchAtLoginMenuController(
            service: service,
            isAvailable: true
        )

        controller.toggleLaunchAtLogin()

        XCTAssertEqual(service.openSettingsCount, 1)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
    }
}

@MainActor
private final class RecordingLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginServiceStatus {
        statusReadCount += 1
        return storedStatus
    }

    private let storedStatus: LaunchAtLoginServiceStatus
    private(set) var statusReadCount = 0
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0
    private(set) var openSettingsCount = 0

    init(status: LaunchAtLoginServiceStatus) {
        storedStatus = status
    }

    func register() throws {
        registerCount += 1
    }

    func unregister() throws {
        unregisterCount += 1
    }

    func openSystemSettingsLoginItems() {
        openSettingsCount += 1
    }
}
