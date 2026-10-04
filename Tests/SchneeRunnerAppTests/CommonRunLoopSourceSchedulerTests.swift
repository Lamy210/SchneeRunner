import CoreFoundation
import Foundation
@testable import SchneeRunnerApp
import XCTest

@MainActor
final class CommonRunLoopSourceSchedulerTests: XCTestCase {
    private final class SourceTarget {
        var didPerform = false
    }

    func testSourcePerformsWhileEventTrackingRunLoopModeIsActive() throws {
        let target = SourceTarget()
        var context = CFRunLoopSourceContext(
            version: 0,
            info: Unmanaged.passUnretained(target).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil,
            equal: nil,
            hash: nil,
            schedule: nil,
            cancel: nil,
            perform: { info in
                guard let info else {
                    return
                }

                let target = Unmanaged<SourceTarget>
                    .fromOpaque(info)
                    .takeUnretainedValue()
                target.didPerform = true
            }
        )
        let source = try XCTUnwrap(
            CFRunLoopSourceCreate(
                kCFAllocatorDefault,
                0,
                &context
            )
        )
        CommonRunLoopSourceScheduler.add(source)
        defer {
            CommonRunLoopSourceScheduler.remove(source)
        }

        CFRunLoopSourceSignal(source)
        CFRunLoopWakeUp(CFRunLoopGetMain())

        let deadline = Date().addingTimeInterval(0.2)
        while !target.didPerform, Date() < deadline {
            RunLoop.main.run(
                mode: .eventTracking,
                before: Date().addingTimeInterval(0.01)
            )
        }

        XCTAssertTrue(target.didPerform)
    }
}
