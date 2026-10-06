@testable import SchneeRunnerCore
import XCTest

final class PomodoroConfigStoreTests: XCTestCase {
    func testMissingValueReturnsApprovedDefaults() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName(defaults)) }
        let store = PomodoroConfigurationStore(defaults: defaults)

        let configuration = try store.load()

        XCTAssertEqual(configuration.focusDuration, 25 * 60)
        XCTAssertEqual(configuration.shortBreakDuration, 5 * 60)
        XCTAssertEqual(configuration.longBreakDuration, 15 * 60)
        XCTAssertEqual(configuration.focusPhasesBeforeLongBreak, 4)
        XCTAssertFalse(configuration.autoStartNextPhase)
    }

    func testSavedConfigurationRoundTrips() throws {
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName(defaults)) }
        let store = PomodoroConfigurationStore(defaults: defaults)
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
        let defaults = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName(defaults)) }
        defaults.set(Data("not-json".utf8), forKey: PomodoroConfigurationStore.defaultKey)
        let store = PomodoroConfigurationStore(defaults: defaults)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? PomodoroConfigurationStoreError, .invalidStoredConfiguration)
        }
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "SchneeRunnerTests.\(UUID().uuidString)"
        return try XCTUnwrap(UserDefaults(suiteName: name))
    }

    private func suiteName(_ defaults: UserDefaults) -> String {
        defaults.volatileDomainNames.first { $0.hasPrefix("SchneeRunnerTests.") } ?? ""
    }
}
