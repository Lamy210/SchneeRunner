enum DesktopPointerInteractionPolicy {
    static func shouldEndInteraction(
        isUserInteracting: Bool,
        isPrimaryButtonPressed: Bool
    ) -> Bool {
        isUserInteracting && !isPrimaryButtonPressed
    }
}
