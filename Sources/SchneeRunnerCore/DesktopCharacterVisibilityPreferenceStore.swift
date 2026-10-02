import Foundation

public struct DesktopCharacterVisibilityPreferenceStore {
    public static let defaultKey = "SchneeRunner.desktopCharacterVisible"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func isVisible() -> Bool {
        guard let storedValue = defaults.object(forKey: key) else {
            return false
        }

        guard let isVisible = storedValue as? Bool else {
            defaults.removeObject(forKey: key)
            return false
        }

        return isVisible
    }

    public func save(_ isVisible: Bool) {
        defaults.set(
            isVisible,
            forKey: key
        )
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
