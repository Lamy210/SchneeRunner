enum DesktopMovePersistenceAction: Equatable {
    case ignore
    case deferUntilInteractionEnds
    case persistNow
}

enum DesktopMovePersistencePolicy {
    static func action(
        isApplyingManagedFrame: Bool,
        isUserInteracting: Bool,
        isAutonomousMovementActive: Bool
    ) -> DesktopMovePersistenceAction {
        if isApplyingManagedFrame {
            return .ignore
        }

        if isUserInteracting {
            return .deferUntilInteractionEnds
        }

        if isAutonomousMovementActive {
            return .ignore
        }

        return .persistNow
    }

    static func shouldPersistDeferredMove(
        wasInteracting: Bool,
        isInteracting: Bool,
        isMovePersistenceDeferred: Bool,
        isLiveResizing: Bool
    ) -> Bool {
        wasInteracting
            && !isInteracting
            && isMovePersistenceDeferred
            && !isLiveResizing
    }
}
