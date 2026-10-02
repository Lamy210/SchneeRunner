@testable import SchneeRunnerCore
import XCTest

final class DesktopCharacterVisibilityStoreTests: XCTestCase {
    func testDefaultsToHidden() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        XCTAssertFalse(fixture.store.isVisible())
    }

    func testSaveAndReadVisibility() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(true)
        XCTAssertTrue(fixture.store.isVisible())

        fixture.store.save(false)
        XCTAssertFalse(fixture.store.isVisible())
    }

    func testInvalidStoredValueIsDiscarded() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.defaults.set(
            "visible",
            forKey: fixture.key
        )

        XCTAssertFalse(fixture.store.isVisible())
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    func testClearRestoresHiddenDefault() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(true)
        fixture.store.clear()

        XCTAssertFalse(fixture.store.isVisible())
    }

    private func makeFixture() throws -> VisibilityPreferenceFixture {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )
        let key = "desktop-character-visible"

        return VisibilityPreferenceFixture(
            suiteName: suiteName,
            defaults: defaults,
            key: key,
            store: DesktopCharacterVisibilityStore(
                defaults: defaults,
                key: key
            )
        )
    }
}

private struct VisibilityPreferenceFixture {
    let suiteName: String
    let defaults: UserDefaults
    let key: String
    let store: DesktopCharacterVisibilityStore

    func cleanup() {
        defaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
