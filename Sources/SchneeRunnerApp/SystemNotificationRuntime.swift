import Foundation

enum SystemNotificationRuntime {
    static func isAvailable(
        bundleIdentifier: String?,
        bundleURL: URL
    ) -> Bool {
        guard
            let bundleIdentifier,
            !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame
    }
}
