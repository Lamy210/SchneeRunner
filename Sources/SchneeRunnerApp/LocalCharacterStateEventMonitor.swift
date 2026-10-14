import Foundation
import SchneeRunnerCore

enum LocalCharacterStateProviderEvent: Equatable {
    case received(LocalCharacterStateEvent)
    case expired(channel: String)
}

@MainActor
final class LocalCharacterStateEventMonitor: NSObject, EventProvider {
    var onEvent: ((LocalCharacterStateProviderEvent) -> Void)?

    // Transitional compatibility surface. CharacterStateCoordinator still consumes
    // these callbacks until the provider-injection migration is complete.
    var onSet: ((String, CharacterState) -> Void)?
    var onClear: ((String) -> Void)?

    private let center = DistributedNotificationCenter.default()
    private var expiryTimers: [String: Timer] = [:]
    private var isStarted = false

    func start() {
        guard !isStarted else {
            return
        }

        center.addObserver(
            self,
            selector: #selector(receiveEvent(_:)),
            name: Notification.Name(
                LocalCharacterStateEvent.notificationName
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
                LocalCharacterStateEvent.notificationName
            ),
            object: nil
        )
        for timer in expiryTimers.values {
            timer.invalidate()
        }
        expiryTimers.removeAll()
        isStarted = false
    }

    @objc
    private func receiveEvent(_ notification: Notification) {
        guard
            let payload = notification.object as? String,
            let event = try? LocalCharacterStateEvent.decodeJSON(
                payload
            )
        else {
            return
        }

        process(event)
    }

    func process(_ event: LocalCharacterStateEvent) {
        cancelExpiry(for: event.channel)
        onEvent?(.received(event))

        switch event.action {
        case .set:
            guard let state = event.state else {
                return
            }

            onSet?(event.channel, state)
            scheduleExpiry(
                for: event.channel,
                after: event.durationSeconds
            )

        case .clear:
            onClear?(event.channel)
        }
    }

    private func scheduleExpiry(
        for channel: String,
        after duration: Double?
    ) {
        guard let duration else {
            return
        }

        expiryTimers[channel] = CommonRunLoopTimerScheduler.schedule(
            timeInterval: duration,
            target: self,
            selector: #selector(expireEvent(_:)),
            userInfo: channel,
            repeats: false
        )
    }

    private func cancelExpiry(for channel: String) {
        expiryTimers.removeValue(forKey: channel)?.invalidate()
    }

    @objc
    private func expireEvent(_ timer: Timer) {
        guard
            let channel = timer.userInfo as? String,
            let activeTimer = expiryTimers[channel],
            activeTimer === timer
        else {
            return
        }

        expiryTimers.removeValue(forKey: channel)
        onEvent?(.expired(channel: channel))
        onClear?(channel)
    }
}
