import Foundation
import SchneeRunnerCore

enum BuildLifecycleProviderEvent: Equatable {
    case received(LocalBuildEvent)
    case expired
}

@MainActor
final class LocalBuildEventMonitor: NSObject, EventProvider {
    var onEvent: ((BuildLifecycleProviderEvent) -> Void)?

    private let center = DistributedNotificationCenter.default()
    private let statePolicy = BuildStatePolicy()
    private var expiryTimer: Timer?
    private var isStarted = false

    func start() {
        guard !isStarted else {
            return
        }

        center.addObserver(
            self,
            selector: #selector(receiveEvent(_:)),
            name: Notification.Name(
                LocalBuildEvent.notificationName
            ),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        isStarted = true
    }

    func stop() {
        guard isStarted else {
            return
        }

        center.removeObserver(
            self,
            name: Notification.Name(
                LocalBuildEvent.notificationName
            ),
            object: nil
        )
        expiryTimer?.invalidate()
        expiryTimer = nil
        isStarted = false
    }

    @objc
    private func receiveEvent(_ notification: Notification) {
        guard
            let payload = notification.object as? String,
            let event = try? LocalBuildEvent.decodeJSON(payload)
        else {
            return
        }

        process(event)
    }

    func process(_ event: LocalBuildEvent) {
        expiryTimer?.invalidate()
        expiryTimer = nil

        onEvent?(.received(event))

        let effect = statePolicy.effect(for: event.phase)
        scheduleExpiry(
            after: effect.durationSeconds
        )
    }

    func scheduleExpiry(after duration: Double?) {
        guard let duration else {
            return
        }

        expiryTimer = CommonRunLoopTimerScheduler.schedule(
            timeInterval: duration,
            target: self,
            selector: #selector(expireEvent),
            userInfo: nil,
            repeats: false
        )
    }

    @objc
    private func expireEvent() {
        expiryTimer = nil
        onEvent?(.expired)
    }
}
