import Foundation

public struct CharacterSelectionStore {
    public static let defaultKey = "SchneeRunner.lastSelectedCharacterID"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func selectedCharacterID() -> UUID? {
        guard let rawValue = defaults.string(forKey: key) else {
            return nil
        }

        guard let id = UUID(uuidString: rawValue) else {
            defaults.removeObject(forKey: key)
            return nil
        }

        return id
    }

    public func save(id: UUID) {
        defaults.set(id.uuidString, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
