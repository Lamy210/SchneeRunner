import Foundation

public struct DesktopClickThroughStore {
    public static let defaultKey = "SchneeRunner.desktopCharacterClickThrough"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func isEnabled() -> Bool {
        guard let storedValue = defaults.object(forKey: key) else {
            return false
        }

        guard let isEnabled = storedValue as? Bool else {
            defaults.removeObject(forKey: key)
            return false
        }

        return isEnabled
    }

    public func save(_ isEnabled: Bool) {
        defaults.set(
            isEnabled,
            forKey: key
        )
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
