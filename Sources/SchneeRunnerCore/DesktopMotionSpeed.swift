import Foundation

public enum DesktopMotionSpeedPreset: String, CaseIterable, Equatable, Sendable {
    case slow
    case normal
    case fast

    public static let defaultPreset: Self = .normal

    public var pointsPerSecond: Double {
        switch self {
        case .slow:
            36
        case .normal:
            DesktopMotionPolicy.defaultSpeedPointsPerSecond
        case .fast:
            120
        }
    }
}

public struct DesktopMotionSpeedPreferenceStore {
    public static let defaultKey = "SchneeRunner.desktopMotionSpeedPreset"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func preset() -> DesktopMotionSpeedPreset {
        guard let storedValue = defaults.object(forKey: key) else {
            return .defaultPreset
        }

        guard
            let rawValue = storedValue as? String,
            let preset = DesktopMotionSpeedPreset(rawValue: rawValue)
        else {
            defaults.removeObject(forKey: key)
            return .defaultPreset
        }

        return preset
    }

    public func save(_ preset: DesktopMotionSpeedPreset) {
        defaults.set(
            preset.rawValue,
            forKey: key
        )
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
