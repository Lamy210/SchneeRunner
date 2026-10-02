@testable import SchneeRunnerCore
import XCTest

final class DesktopCharacterPlacementStoreTests: XCTestCase {
    func testSaveAndReadPlacement() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let placement = DesktopCharacterPlacement(
            x: 120,
            y: 80,
            width: 160,
            height: 160
        )

        fixture.store.save(placement)

        XCTAssertEqual(
            fixture.store.placement(),
            placement
        )
    }

    func testInvalidStoredPlacementIsDiscarded() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let invalidPlacement = DesktopCharacterPlacement(
            x: 0,
            y: 0,
            width: 32,
            height: 32
        )
        try fixture.defaults.set(
            JSONEncoder().encode(invalidPlacement),
            forKey: fixture.key
        )

        XCTAssertNil(fixture.store.placement())
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    func testSaveInvalidPlacementClearsExistingValue() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(
            DesktopCharacterPlacement(
                x: 10,
                y: 10,
                width: 128,
                height: 128
            )
        )
        fixture.store.save(
            DesktopCharacterPlacement(
                x: 10,
                y: 10,
                width: 1024,
                height: 1024
            )
        )

        XCTAssertNil(fixture.store.placement())
    }

    func testClearRemovesPlacement() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(
            DesktopCharacterPlacement(
                x: 10,
                y: 10,
                width: 128,
                height: 128
            )
        )
        fixture.store.clear()

        XCTAssertNil(fixture.store.placement())
    }

    private func makeFixture() throws -> PlacementFixture {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )
        let key = "desktop-placement"

        return PlacementFixture(
            suiteName: suiteName,
            defaults: defaults,
            key: key,
            store: DesktopCharacterPlacementStore(
                defaults: defaults,
                key: key
            )
        )
    }
}

private struct PlacementFixture {
    let suiteName: String
    let defaults: UserDefaults
    let key: String
    let store: DesktopCharacterPlacementStore

    func cleanup() {
        defaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
