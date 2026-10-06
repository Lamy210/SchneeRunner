import Foundation

public enum ProductivityTimerState: String, Codable, Equatable, Sendable {
    case running
    case paused
    case completed
    case cancelled
}

public enum ProductivityCountdownTimerError: Error, Equatable, Sendable {
    case invalidDuration
    case invalidStateTransition
    case invalidStoredState
}

public struct ProductivityCountdownTimer: Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let originalDuration: TimeInterval
    public let startedAt: Date?
    public let deadline: Date?
    public let pausedRemaining: TimeInterval?
    public let state: ProductivityTimerState
    public let completedAt: Date?

    public init(
        id: UUID,
        title: String,
        duration: TimeInterval,
        startedAt: Date
    ) throws {
        guard duration.isFinite, duration > 0 else {
            throw ProductivityCountdownTimerError.invalidDuration
        }

        self.init(
            id: id,
            title: title,
            originalDuration: duration,
            startedAt: startedAt,
            deadline: startedAt.addingTimeInterval(duration),
            pausedRemaining: nil,
            state: .running,
            completedAt: nil
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let originalDuration = try container.decode(TimeInterval.self, forKey: .originalDuration)
        let startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        let deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        let pausedRemaining = try container.decodeIfPresent(TimeInterval.self, forKey: .pausedRemaining)
        let state = try container.decode(ProductivityTimerState.self, forKey: .state)
        let completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)

        try Self.validateStoredState(
            originalDuration: originalDuration,
            deadline: deadline,
            pausedRemaining: pausedRemaining,
            state: state,
            completedAt: completedAt
        )

        self.init(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: deadline,
            pausedRemaining: pausedRemaining,
            state: state,
            completedAt: completedAt
        )
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .running:
            guard let deadline else {
                return 0
            }
            return max(0, deadline.timeIntervalSince(now))
        case .paused:
            return max(0, pausedRemaining ?? 0)
        case .completed, .cancelled:
            return 0
        }
    }

    public func pausing(at now: Date) throws -> ProductivityCountdownTimer {
        guard
            state == .running,
            let deadline
        else {
            throw ProductivityCountdownTimerError.invalidStateTransition
        }

        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else {
            throw ProductivityCountdownTimerError.invalidStateTransition
        }

        return ProductivityCountdownTimer(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: nil,
            pausedRemaining: remaining,
            state: .paused,
            completedAt: nil
        )
    }

    public func resuming(at now: Date) throws -> ProductivityCountdownTimer {
        guard
            state == .paused,
            let pausedRemaining,
            pausedRemaining > 0
        else {
            throw ProductivityCountdownTimerError.invalidStateTransition
        }

        return ProductivityCountdownTimer(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: now.addingTimeInterval(pausedRemaining),
            pausedRemaining: nil,
            state: .running,
            completedAt: nil
        )
    }

    public func cancelling() -> ProductivityCountdownTimer {
        guard state != .completed, state != .cancelled else {
            return self
        }

        return ProductivityCountdownTimer(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: nil,
            pausedRemaining: nil,
            state: .cancelled,
            completedAt: nil
        )
    }

    public func reconciling(at now: Date) -> ProductivityCountdownTimer {
        guard
            state == .running,
            let deadline,
            deadline <= now
        else {
            return self
        }

        return ProductivityCountdownTimer(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: nil,
            pausedRemaining: nil,
            state: .completed,
            completedAt: deadline
        )
    }

    private static func validateStoredState(
        originalDuration: TimeInterval,
        deadline: Date?,
        pausedRemaining: TimeInterval?,
        state: ProductivityTimerState,
        completedAt: Date?
    ) throws {
        guard originalDuration.isFinite, originalDuration > 0 else {
            throw ProductivityCountdownTimerError.invalidStoredState
        }

        let isValid = switch state {
        case .running:
            deadline != nil && pausedRemaining == nil && completedAt == nil
        case .paused:
            deadline == nil && isValidPausedRemaining(pausedRemaining) && completedAt == nil
        case .completed:
            deadline == nil && pausedRemaining == nil && completedAt != nil
        case .cancelled:
            deadline == nil && pausedRemaining == nil && completedAt == nil
        }

        guard isValid else {
            throw ProductivityCountdownTimerError.invalidStoredState
        }
    }

    private static func isValidPausedRemaining(_ value: TimeInterval?) -> Bool {
        guard let value else {
            return false
        }
        return value.isFinite && value > 0
    }

    private init(
        id: UUID,
        title: String,
        originalDuration: TimeInterval,
        startedAt: Date?,
        deadline: Date?,
        pausedRemaining: TimeInterval?,
        state: ProductivityTimerState,
        completedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.originalDuration = originalDuration
        self.startedAt = startedAt
        self.deadline = deadline
        self.pausedRemaining = pausedRemaining
        self.state = state
        self.completedAt = completedAt
    }
}
