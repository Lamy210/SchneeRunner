import Foundation
import SchneeRunnerCore

@MainActor
final class LocalCharacterStateEventMonitor: NSObject {
    var onSet: ((CharacterState) -> Void)?
    var onClear: (() -> Void)?

    private let center = DistributedNotificationCenter.default()
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
        expiryTimer?.invalidate()
        expiryTimer = nil
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

        handle(event)
    }

    private func handle(_ event: LocalCharacterStateEvent) {
        expiryTimer?.invalidate()
        expiryTimer = nil

        switch event.action {
        case .set:
            guard let state = event.state else {
                return
            }

            onSet?(state)
            scheduleExpiry(
                after: event.durationSeconds
            )

        case .clear:
            onClear?()
        }
    }

    private func scheduleExpiry(after duration: Double?) {
        guard let duration else {
            return
        }

        expiryTimer = Timer.scheduledTimer(
            withTimeInterval: duration,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.expiryTimer = nil
                self?.onClear?()
            }
        }
    }
}
