import Foundation
@testable import SchneeRunnerCore
import XCTest

final class PomodoroConfigStoreTests: XCTestCase {
    func testMissingValueReturnsApprovedDefaults() throws {
        let fixture = try makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let store = PomodoroConfigurationStore(defaults: fixture.defaults)

        let configuration = try store.load()

        XCTAssertEqual(configuration.focusDuration, 25 * 60)
        XCTAssertEqual(configuration.shortBreakDuration, 5 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 15 * 60)
        XCTAssertEqual(configuration.focusPhasesBeforeLongBreak, 4)
        XCTAssertFalse(configuration.autoStartNextPhase)
    }

    func testSavedConfigurationRoundTrips() throws {
        let fixture = try makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        let store = PomodoroConfigurationStore(defaults: fixture.defaults)
        let expected = try PomodoroConfiguration(
            focusDuration: 50 * 60,
            shortBreakDuration: 10 * 60,
            longBreakDuration: 30 * 60,
            focusPhasesBeforeLongBreak: 3,
            autoStartNextPhase: true
        )

        try store.save(expected)

        XCTAssertEqual(try store.load(), expected)
    }

    func testMalformedStoredValueFailsClosed() throws {
        let fixture = try makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        fixture.defaults.set(
            Data("not-json".utf8),
            forKey: PomodoroConfigurationStore.defaultKey
        )
        let store = PomodoroConfigurationStore(defaults: fixture.defaults)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? PomodoroConfigurationStoreError,
                .invalidStoredConfiguration
            )
        }
    }

    func testWrongStoredTypeFailsClosed() throws {
        let fixture = try makeDefaults()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.name) }
        fixture.defaults.set(
            "not-data",
            forKey: PomodoroConfigurationStore.defaultKey
        )
        let store = PomodoroConfigurationStore(defaults: fixture.defaults)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(
                error as? PomodoroConfigurationStoreError,
                .invalidStoredConfiguration
            )
        }
    }

    private func makeDefaults() throws -> (
        defaults: UserDefaults,
        name: String
    ) {
        let name = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        return (defaults, name)
    }
}
