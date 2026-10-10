import Foundation

enum SystemNotificationRuntime {
    private static let enabledInfoPlistKey = "SchneeRunnerSystemNotificationsEnabled"

    static var mainBundleNotificationsEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: enabledInfoPlistKey) as? Bool ?? true
    }

    static func isAvailable(
        bundleIdentifier: String?,
        bundleURL: URL,
        notificationsEnabled: Bool = mainBundleNotificationsEnabled
    ) -> Bool {
        RuntimeCapabilities.detect(
            bundleIdentifier: bundleIdentifier,
            bundleURL: bundleURL,
            notificationsEnabled: notificationsEnabled,
            resourceURL: Bundle.main.resourceURL
        ).systemNotificationsAvailable
    }
}
