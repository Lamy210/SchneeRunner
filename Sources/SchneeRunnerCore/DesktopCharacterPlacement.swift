import Foundation

public struct DesktopCharacterPlacement: Codable, Equatable, Sendable {
    public static let minimumDimension = 64.0
    public static let maximumDimension = 512.0

    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        x.isFinite
            && y.isFinite
            && width.isFinite
            && height.isFinite
            && width >= Self.minimumDimension
            && width <= Self.maximumDimension
            && height >= Self.minimumDimension
            && height <= Self.maximumDimension
    }
}

public struct DesktopCharacterPlacementStore {
    public static let defaultKey = "SchneeRunner.desktopCharacterPlacement"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = Self.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func placement() -> DesktopCharacterPlacement? {
        guard
            let data = defaults.data(forKey: key),
            let placement = try? JSONDecoder().decode(
                DesktopCharacterPlacement.self,
                from: data
            ),
            placement.isValid
        else {
            defaults.removeObject(forKey: key)
            return nil
        }

        return placement
    }

    public func save(_ placement: DesktopCharacterPlacement) {
        guard
            placement.isValid,
            let data = try? JSONEncoder().encode(placement)
        else {
            defaults.removeObject(forKey: key)
            return
        }

        defaults.set(
            data,
            forKey: key
        )
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
