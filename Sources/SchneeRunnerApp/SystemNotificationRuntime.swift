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
        guard notificationsEnabled else {
            return false
        }

        guard
            let bundleIdentifier,
            !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }
}
