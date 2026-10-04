import Foundation
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class CommonRunLoopTimerSchedulerTests: XCTestCase {
    private final class TimerTarget: NSObject {
        var didFire = false

        @objc
        func timerDidFire(_: Timer) {
            didFire = true
        }
    }

    func testTimerFiresWhileEventTrackingRunLoopModeIsActive() {
        let target = TimerTarget()
        let timer = CommonRunLoopTimerScheduler.schedule(
            timeInterval: 0.01,
            target: target,
            selector: #selector(TimerTarget.timerDidFire(_:)),
            userInfo: nil,
            repeats: false
        )
        defer {
            timer.invalidate()
        }

        let deadline = Date().addingTimeInterval(0.2)
        while !target.didFire, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertTrue(target.didFire)
    }
}
