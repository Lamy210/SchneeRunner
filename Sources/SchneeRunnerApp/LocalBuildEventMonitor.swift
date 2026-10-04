import Foundation
import SchneeRunnerCore

@MainActor
final class LocalBuildEventMonitor: NSObject {
    var onSet: ((CharacterState) -> Void)?
    var onClear: (() -> Void)?

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

        handle(event)
    }

    private func handle(_ event: LocalBuildEvent) {
        expiryTimer?.invalidate()
        expiryTimer = nil

        let effect = statePolicy.effect(for: event.phase)
        guard let state = effect.state else {
            onClear?()
            return
        }

        onSet?(state)
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
        onClear?()
    }
}
