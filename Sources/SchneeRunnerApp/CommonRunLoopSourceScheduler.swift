import CoreFoundation
import Foundation

@MainActor
enum CommonRunLoopSourceScheduler {
    private static let eventTrackingMode = CFRunLoopMode(
        rawValue: RunLoop.Mode.eventTracking.rawValue as CFString
    )

    static func add(_ source: CFRunLoopSource) {
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(
            runLoop,
            source,
            .commonModes
        )
        CFRunLoopAddSource(
            runLoop,
            source,
            eventTrackingMode
        )
    }

    static func remove(_ source: CFRunLoopSource) {
        let runLoop = CFRunLoopGetMain()
        CFRunLoopRemoveSource(
            runLoop,
            source,
            .commonModes
        )
        CFRunLoopRemoveSource(
            runLoop,
            source,
            eventTrackingMode
        )
    }
}
