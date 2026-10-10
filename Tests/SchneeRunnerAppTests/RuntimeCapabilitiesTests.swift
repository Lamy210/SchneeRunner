import Foundation
@testable import SchneeRunnerApp
import XCTest

final class RuntimeCapabilitiesTests: XCTestCase {
    func testBareExecutableDisablesPackagedOnlyCapabilitiesButKeepsFallbackAvailable() {
        let capabilities = RuntimeCapabilities.detect(
            bundleIdentifier: nil,
            bundleURL: URL(fileURLWithPath: "/tmp/SchneeRunner"),
            notificationsEnabled: true,
            resourceURL: URL(fileURLWithPath: "/tmp/resources", isDirectory: true)
        )

        XCTAssertFalse(capabilities.systemNotificationsAvailable)
        XCTAssertFalse(capabilities.launchAtLoginAvailable)
        XCTAssertTrue(capabilities.bundledResourcesAvailable)
        XCTAssertTrue(capabilities.inProcessFallbackAvailable)
    }

    func testUnsignedApplicationBundleKeepsFallbackWhenSystemNotificationsAreOptedOut() {
        let capabilities = RuntimeCapabilities.detect(
            bundleIdentifier: "io.github.Lamy210.SchneeRunner",
            bundleURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app", isDirectory: true),
            notificationsEnabled: false,
            resourceURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app/Contents/Resources", isDirectory: true)
        )

        XCTAssertFalse(capabilities.systemNotificationsAvailable)
        XCTAssertTrue(capabilities.launchAtLoginAvailable)
        XCTAssertTrue(capabilities.bundledResourcesAvailable)
        XCTAssertTrue(capabilities.inProcessFallbackAvailable)
    }

    func testApplicationBundleCanEnableSystemNotifications() {
        let capabilities = RuntimeCapabilities.detect(
            bundleIdentifier: "io.github.Lamy210.SchneeRunner",
            bundleURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app", isDirectory: true),
            notificationsEnabled: true,
            resourceURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app/Contents/Resources", isDirectory: true)
        )

        XCTAssertTrue(capabilities.systemNotificationsAvailable)
        XCTAssertTrue(capabilities.launchAtLoginAvailable)
        XCTAssertTrue(capabilities.inProcessFallbackAvailable)
    }

    func testMissingResourceURLOnlyDisablesBundledResources() {
        let capabilities = RuntimeCapabilities.detect(
            bundleIdentifier: "io.github.Lamy210.SchneeRunner",
            bundleURL: URL(fileURLWithPath: "/Applications/SchneeRunner.app", isDirectory: true),
            notificationsEnabled: false,
            resourceURL: nil
        )

        XCTAssertFalse(capabilities.systemNotificationsAvailable)
        XCTAssertTrue(capabilities.launchAtLoginAvailable)
        XCTAssertFalse(capabilities.bundledResourcesAvailable)
        XCTAssertTrue(capabilities.inProcessFallbackAvailable)
    }
}
