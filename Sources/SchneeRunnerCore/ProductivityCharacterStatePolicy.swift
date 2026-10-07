public enum ProductivityCharacterStateSignal: Equatable, Sendable {
    case breakPhase
    case activeCountdown
    case pomodoroFocus
    case finalMinute
    case timerCompleted
    case reminderFired
}

public struct ProductivityCharacterStatePolicy: Sendable {
    public init() {}

    public func state(
        for signals: [ProductivityCharacterStateSignal]
    ) -> CharacterState? {
        if signals.contains(.reminderFired) {
            return .idle
        }
        if signals.contains(.timerCompleted) {
            return .sprint
        }
        if signals.contains(.finalMinute) {
            return .sprint
        }
        if signals.contains(.pomodoroFocus) {
            return .dash
        }
        if signals.contains(.activeCountdown) {
            return .walk
        }
        if signals.contains(.breakPhase) {
            return .idle
        }
        return nil
    }
}
