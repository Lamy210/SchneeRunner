import Foundation

public enum ProductivityTimerState: String, Codable, Equatable, Sendable {
    case running
    case paused
    case completed
    case cancelled
}

public enum ProductivityCountdownTimerError: Error, Equatable, Sendable {
    case invalidDuration(TimeInterval)
    case invalidTransition(
        from: ProductivityTimerState,
        to: ProductivityTimerState
    )
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
        guard duration > 0 else {
            throw ProductivityCountdownTimerError.invalidDuration(duration)
        }

        self.id = id
        self.title = title
        originalDuration = duration
        self.startedAt = startedAt
        deadline = startedAt.addingTimeInterval(duration)
        pausedRemaining = nil
        state = .running
        completedAt = nil
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

        let remainingDuration = remaining(at: now)
        if remainingDuration == 0 {
            return reconciling(at: now)
        }

        return ProductivityCountdownTimer(
            id: id,
            title: title,
            originalDuration: originalDuration,
            startedAt: startedAt,
            deadline: nil,
            pausedRemaining: remainingDuration,
            state: .paused,
            completedAt: nil
        )
    }

    public func resuming(at now: Date) throws -> ProductivityCountdownTimer {
        guard state == .paused, let pausedRemaining, pausedRemaining > 0 else {
            throw ProductivityCountdownTimerError.invalidTransition(
                from: state,
                to: .running
            )
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
}

private extension ProductivityCountdownTimer {
    init(
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
