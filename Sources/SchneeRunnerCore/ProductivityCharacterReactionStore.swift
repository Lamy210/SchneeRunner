import Foundation

public struct ProductivityCharacterReactionStore {
    public static let defaultKey = "SchneeRunner.productivityCharacterReactionsEnabled"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var isEnabled: Bool {
        get {
            guard let storedValue = defaults.object(forKey: key) else {
                return true
            }
            return storedValue as? Bool ?? true
        }
        nonmutating set {
            defaults.set(newValue, forKey: key)
        }
    }
}
