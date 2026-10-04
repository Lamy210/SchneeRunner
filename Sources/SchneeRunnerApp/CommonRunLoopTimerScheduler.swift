import Foundation

@MainActor
enum CommonRunLoopTimerScheduler {
    @discardableResult
    static func schedule(
        timeInterval: TimeInterval,
        target: Any,
        selector: Selector,
        userInfo: Any?,
        repeats: Bool
    ) -> Timer {
        let timer = Timer(
            timeInterval: timeInterval,
            target: target,
            selector: selector,
            userInfo: userInfo,
            repeats: repeats
        )
        RunLoop.main.add(
            timer,
            forMode: .common
        )
        RunLoop.main.add(
            timer,
            forMode: .eventTracking
        )
        return timer
    }
}
