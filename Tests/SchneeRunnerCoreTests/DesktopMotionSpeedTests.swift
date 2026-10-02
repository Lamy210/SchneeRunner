@testable import SchneeRunnerCore
import XCTest

final class DesktopMotionSpeedTests: XCTestCase {
    func testPresetSpeeds() {
        XCTAssertEqual(
            DesktopMotionSpeedPreset.slow.pointsPerSecond,
            36
        )
        XCTAssertEqual(
            DesktopMotionSpeedPreset.normal.pointsPerSecond,
            DesktopMotionPolicy.defaultSpeedPointsPerSecond
        )
        XCTAssertEqual(
            DesktopMotionSpeedPreset.fast.pointsPerSecond,
            120
        )
    }

    func testDefaultPresetIsNormal() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        XCTAssertEqual(
            fixture.store.preset(),
            .normal
        )
    }

    func testSaveAndReadPreset() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(.fast)

        XCTAssertEqual(
            fixture.store.preset(),
            .fast
        )
    }

    func testInvalidStoredPresetIsDiscarded() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.defaults.set(
            "warp",
            forKey: fixture.key
        )

        XCTAssertEqual(
            fixture.store.preset(),
            .normal
        )
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    func testInvalidStoredPresetTypeIsDiscarded() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.defaults.set(
            120,
            forKey: fixture.key
        )

        XCTAssertEqual(
            fixture.store.preset(),
            .normal
        )
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    func testClearRestoresDefaultPreset() throws {
        let fixture = try makeFixture()
        defer {
            fixture.cleanup()
        }

        fixture.store.save(.slow)
        fixture.store.clear()

        XCTAssertEqual(
            fixture.store.preset(),
            .normal
        )
        XCTAssertNil(
            fixture.defaults.object(forKey: fixture.key)
        )
    }

    private func makeFixture() throws -> MotionSpeedFixture {
        let suiteName = "SchneeRunnerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(
            UserDefaults(suiteName: suiteName)
        )
        let key = "desktop-motion-speed"

        return MotionSpeedFixture(
            suiteName: suiteName,
            defaults: defaults,
            key: key,
            store: DesktopMotionSpeedPreferenceStore(
                defaults: defaults,
                key: key
            )
        )
    }
}

private struct MotionSpeedFixture {
    let suiteName: String
    let defaults: UserDefaults
    let key: String
    let store: DesktopMotionSpeedPreferenceStore

    func cleanup() {
        defaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
