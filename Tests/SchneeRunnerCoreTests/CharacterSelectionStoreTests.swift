@testable import SchneeRunnerCore
import XCTest

final class CharacterSelectionStoreTests: XCTestCase {
    func testSaveAndReadSelectedCharacterID() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        let id = UUID()
        fixture.store.save(id: id)

        XCTAssertEqual(
            fixture.store.selectedCharacterID(),
            id
        )
    }

    func testInvalidStoredValueIsDiscarded() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.defaults.set(
            "not-a-uuid",
            forKey: fixture.key
        )

        XCTAssertNil(fixture.store.selectedCharacterID())
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    func testClearRemovesSelection() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(id: UUID())
        fixture.store.clear()

        XCTAssertNil(fixture.store.selectedCharacterID())
    }

    private func makeFixture() throws -> SelectionFixture {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )
        let key = "selected"

        return SelectionFixture(
            suiteName: suiteName,
            defaults: defaults,
            key: key,
            store: CharacterSelectionStore(
                defaults: defaults,
                key: key
            )
        )
    }
}

private struct SelectionFixture {
    let suiteName: String
    let defaults: UserDefaults
    let key: String
    let store: CharacterSelectionStore

    func cleanup() {
        defaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
