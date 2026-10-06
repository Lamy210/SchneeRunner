import Foundation

public enum PomodoroConfigurationStoreError: Error, Equatable, Sendable {
    case invalidStoredConfiguration
}

public struct PomodoroConfigurationStore {
    public static let defaultKey = "SchneeRunner.pomodoroConfiguration"

    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.key = key
        self.encoder = encoder
        self.decoder = decoder
    }

    public func load() throws -> PomodoroConfiguration {
        guard let storedValue = defaults.object(forKey: key) else {
            return try PomodoroConfiguration()
        }
        guard let data = storedValue as? Data else {
            throw PomodoroConfigurationStoreError.invalidStoredConfiguration
        }

        do {
            return try decoder.decode(PomodoroConfiguration.self, from: data)
        } catch {
            throw PomodoroConfigurationStoreError.invalidStoredConfiguration
        }
    }

    public func save(_ configuration: PomodoroConfiguration) throws {
        try defaults.set(
            encoder.encode(configuration),
            forKey: key
        )
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
