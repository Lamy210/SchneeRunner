import Foundation

struct RuntimeCapabilities: Equatable, Sendable {
    let systemNotificationsAvailable: Bool
    let launchAtLoginAvailable: Bool
    let bundledResourcesAvailable: Bool
    let inProcessFallbackAvailable: Bool

    static func detect(
        bundleIdentifier: String?,
        bundleURL: URL,
        notificationsEnabled: Bool,
        resourceURL: URL?
    ) -> RuntimeCapabilities {
        let hasBundleIdentifier = bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let isApplicationBundle = bundleURL.pathExtension
            .caseInsensitiveCompare("app") == .orderedSame

        return RuntimeCapabilities(
            systemNotificationsAvailable:
                notificationsEnabled && hasBundleIdentifier && isApplicationBundle,
            launchAtLoginAvailable: hasBundleIdentifier && isApplicationBundle,
            bundledResourcesAvailable: resourceURL != nil,
            inProcessFallbackAvailable: true
        )
    }
}
