@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

final class CPUStatusFormatterTests: XCTestCase {
    func testSamplingStatusIncludesStateAndAdaptivePlaybackRate() {
        XCTAssertEqual(
            CPUStatusFormatter.title(
                status: .sampling,
                requestedState: .sprint,
                resolvedState: .run,
                playbackRate: 1,
                isAdaptiveSpeedEnabled: true
            ),
            "CPU: sampling… · Sprint → Run · 1×"
        )
    }

    func testUnavailableStatusIncludesStateAndManualPlaybackRate() {
        XCTAssertEqual(
            CPUStatusFormatter.title(
                status: .unavailable,
                requestedState: .run,
                resolvedState: .run,
                playbackRate: 1.5,
                isAdaptiveSpeedEnabled: false
            ),
            "CPU: unavailable · Run · Manual 1.5×"
        )
    }

    func testUtilizationStatusRoundsPercentage() {
        XCTAssertEqual(
            CPUStatusFormatter.title(
                status: .utilization(0.426),
                requestedState: .run,
                resolvedState: .run,
                playbackRate: 1,
                isAdaptiveSpeedEnabled: true
            ),
            "CPU: 43% · Run · 1×"
        )
    }

    func testJapaneseSamplingStatusLocalizesStateAndStatus() {
        let localization = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(
            CPUStatusFormatter.title(
                status: .sampling,
                requestedState: .sprint,
                resolvedState: .run,
                playbackRate: 1,
                isAdaptiveSpeedEnabled: true,
                localization: localization
            ),
            "CPU: 計測中… · 全力疾走 → 走行 · 1×"
        )
    }

    func testJapaneseUnavailableStatusLocalizesManualPlaybackLabel() {
        let localization = AppLocalization(localeIdentifier: "ja")

        XCTAssertEqual(
            CPUStatusFormatter.title(
                status: .unavailable,
                requestedState: .run,
                resolvedState: .run,
                playbackRate: 1.5,
                isAdaptiveSpeedEnabled: false,
                localization: localization
            ),
            "CPU: 利用不可 · 走行 · 手動 1.5×"
        )
    }
}
