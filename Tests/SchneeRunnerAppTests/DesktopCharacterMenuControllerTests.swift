@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class DesktopCharacterMenuControllerTests: XCTestCase {
    func testRestoresPersistedDesktopConfigurationWithoutAutomaticMovement() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.visibilityStore.save(true)
        fixture.clickThroughStore.save(true)
        fixture.movementSpeedStore.save(.fast)

        let controller = DesktopCharacterMenuController(
            visibilityStore: fixture.visibilityStore,
            movementSpeedStore: fixture.movementSpeedStore,
            clickThroughStore: fixture.clickThroughStore
        )

        XCTAssertEqual(
            controller.configuration,
            DesktopCharacterMenuConfiguration(
                isVisible: true,
                isAutonomousMovementEnabled: false,
                isClickThroughEnabled: true,
                movementSpeed: .fast
            )
        )
    }

    func testDefaultsToHiddenNormalNonClickThroughConfiguration() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let controller = DesktopCharacterMenuController(
            visibilityStore: fixture.visibilityStore,
            movementSpeedStore: fixture.movementSpeedStore,
            clickThroughStore: fixture.clickThroughStore
        )

        XCTAssertEqual(
            controller.configuration,
            DesktopCharacterMenuConfiguration(
                isVisible: false,
                isAutonomousMovementEnabled: false,
                isClickThroughEnabled: false,
                movementSpeed: .normal
            )
        )
    }

    private func makeFixture() throws -> DesktopMenuFixture {
        let suiteName = "SchneeRunnerAppTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )

        return DesktopMenuFixture(
            suiteName: suiteName,
            defaults: defaults,
            visibilityStore: DesktopCharacterVisibilityStore(
                defaults: defaults,
                key: "desktop-visible"
            ),
            movementSpeedStore: DesktopMotionSpeedPreferenceStore(
                defaults: defaults,
                key: "desktop-motion-speed"
            ),
            clickThroughStore: DesktopClickThroughStore(
                defaults: defaults,
                key: "desktop-click-through"
            )
        )
    }
}

private struct DesktopMenuFixture {
    let suiteName: String
    let defaults: UserDefaults
    let visibilityStore: DesktopCharacterVisibilityStore
    let movementSpeedStore: DesktopMotionSpeedPreferenceStore
    let clickThroughStore: DesktopClickThroughStore

    func cleanup() {
        defaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
