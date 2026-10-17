import Foundation
@testable import SchneeRunnerApp
import XCTest

final class AppLocalizationRuntimeBundleTests: XCTestCase {
    func testLocalizationCanResolveResourcesThroughRuntimeMainBundle() {
        let runtimeBundle = BuiltInCharacterResources.moduleBundle

        let localization = AppLocalization(
            localeIdentifier: "ja",
            resourceBundle: nil,
            mainBundle: runtimeBundle
        )

        XCTAssertEqual(localization.string("menu.timers"), "タイマー")
    }
}
