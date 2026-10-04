import CoreFoundation
import Foundation

@MainActor
enum CommonRunLoopSourceScheduler {
    private static let eventTrackingMode = RunLoop.Mode.eventTracking.rawValue as CFString

    static func add(_ source: CFRunLoopSource) {
        let runLoop = CFRunLoopGetMain()
        CFRunLoopAddSource(
            runLoop,
            source,
            kCFRunLoopCommonModes
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
            kCFRunLoopCommonModes
        )
        CFRunLoopRemoveSource(
            runLoop,
            source,
            eventTrackingMode
        )
    }
}
