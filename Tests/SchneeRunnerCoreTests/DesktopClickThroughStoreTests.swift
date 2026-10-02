@testable import SchneeRunnerCore
import XCTest

final class DesktopClickThroughStoreTests: XCTestCase {
    func testDefaultsToDisabled() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        XCTAssertFalse(fixture.store.isEnabled())
    }

    func testSaveAndReadState() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(true)
        XCTAssertTrue(fixture.store.isEnabled())

        fixture.store.save(false)
        XCTAssertFalse(fixture.store.isEnabled())
    }

    func testInvalidStoredValueIsDiscarded() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.defaults.set(
            "enabled",
            forKey: fixture.key
        )

        XCTAssertFalse(fixture.store.isEnabled())
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    func testClearRestoresDisabledDefault() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(true)
        fixture.store.clear()

        XCTAssertFalse(fixture.store.isEnabled())
    }

    private func makeFixture() throws -> ClickThroughFixture {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )
        let key = "desktop-click-through"

        return ClickThroughFixture(
            suiteName: suiteName,
            defaults: defaults,
            key: key,
            store: DesktopClickThroughStore(
                defaults: defaults,
                key: key
            )
        )
    }
}

private struct ClickThroughFixture {
    let suiteName: String
    let defaults: UserDefaults
    let key: String
    let store: DesktopClickThroughStore

    func cleanup() {
        defaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
