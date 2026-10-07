import Foundation
import SchneeRunnerCore
import XCTest

final class ProductivityCharacterReactionStoreTests: XCTestCase {
    func testMissingPreferenceDefaultsToEnabled() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        XCTAssertTrue(fixture.store.isEnabled)
    }

    func testPreferenceRoundTripsDisabledAndEnabled() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        fixture.store.isEnabled = false
        XCTAssertFalse(fixture.store.isEnabled)

        fixture.store.isEnabled = true
        XCTAssertTrue(fixture.store.isEnabled)
    }

    func testStoredBooleanIsSharedAcrossStoreInstances() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }

        fixture.store.isEnabled = false
        let reloaded = ProductivityCharacterReactionStore(
            defaults: fixture.defaults,
            key: fixture.key
        )

        XCTAssertFalse(reloaded.isEnabled)
    }
}

private extension ProductivityCharacterReactionStoreTests {
    struct Fixture {
        let defaults: UserDefaults
        let key: String
        let store: ProductivityCharacterReactionStore
        let suiteName: String

        func cleanup() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    func makeFixture() throws -> Fixture {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let key = "productivity-character-reactions"
        return Fixture(
            defaults: defaults,
            key: key,
            store: ProductivityCharacterReactionStore(
                defaults: defaults,
                key: key
            ),
            suiteName: suiteName
        )
    }
}
