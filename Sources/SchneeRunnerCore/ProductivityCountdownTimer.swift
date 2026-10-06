import Foundation

public enum ProductivityTimerState: String, Codable, Equatable, Sendable {
    case running
    case paused
    case completed
    case cancelled
}

public enum ProductivityCountdownTimerError: Error, Equatable, Sendable {
    case nonPositiveDuration
    case invalidPersistedState
    case invalidTransition(from: ProductivityTimerState, to: ProductivityTimerState)
    case noRemainingTime
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
            throw ProductivityCountdownTimerError.nonPositiveDuration
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
        guard state == .running else {
            throw ProductivityCountdownTimerError.invalidTransition(
                from: state,
                to: .paused
            )
        }

        let remaining = remaining(at: now)
        guard remaining > 0 else {
            throw ProductivityCountdownTimerError.noRemainingTime
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
        guard state == .paused else {
            throw ProductivityCountdownTimerError.invalidTransition(
                from: state,
                to: .running
            )
        }
        guard let pausedRemaining, pausedRemaining > 0 else {
            throw ProductivityCountdownTimerError.noRemainingTime
        }

        return ProductivityCountdownTimer(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: now,
            deadline: now.addingTimeInterval(pausedRemaining),
            pausedRemaining: nil,
            state: .running,
            completedAt: nil
        )
    }

    public func cancelling() -> ProductivityCountdownTimer {
        guard state == .running || state == .paused else {
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
        guard state == .running, remaining(at: now) == 0 else {
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
            completedAt: now
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

        guard Self.isValid(
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: deadline,
            pausedRemaining: pausedRemaining,
            state: state,
            completedAt: completedAt
        ) else {
            throw ProductivityCountdownTimerError.invalidPersistedState
        }

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

    private static func isValid(
        originalDuration: TimeInterval,
        startedAt: Date?,
        deadline: Date?,
        pausedRemaining: TimeInterval?,
        state: ProductivityTimerState,
        completedAt: Date?
    ) -> Bool {
        guard originalDuration.isFinite, originalDuration > 0 else {
            return false
        }

        switch state {
        case .running:
            guard let startedAt, let deadline else {
                return false
            }
            return deadline > startedAt && pausedRemaining == nil && completedAt == nil
        case .paused:
            guard startedAt != nil, let pausedRemaining else {
                return false
            }
            return pausedRemaining.isFinite && pausedRemaining > 0 && deadline == nil && completedAt == nil
        case .completed:
            return startedAt != nil && deadline == nil && pausedRemaining == nil && completedAt != nil
        case .cancelled:
            return startedAt != nil && deadline == nil && pausedRemaining == nil && completedAt == nil
        }
    }
}
